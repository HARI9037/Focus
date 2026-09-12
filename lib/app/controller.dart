import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../core/database/repository.dart';
import '../core/logging/log.dart';
import '../core/platform/device_bridge.dart';
import '../features/tasks/domain/entry.dart';
import '../core/sync/local_sync.dart';

class FocusController extends ChangeNotifier {
  final LocalRepository repository;
  final DeviceBridge device;
  List<Entry> entries = [];
  List<Map<String, Object?>> usage = [];
  Map<String, dynamic> settings = {}, phone = {};
  String? error;
  bool busy = false;
  Timer? _ticker;
  bool _finishing = false;
  Future<void> _pending = Future<void>.value();
  bool _disposed = false;
  String? notice;
  final LocalSync sync = LocalSync();
  Future<String> syncPayload() async {
    final data = jsonDecode(await exportBackup()) as Map<String, dynamic>;
    data['platform'] = Platform.isAndroid ? 'android' : 'windows';
    return jsonEncode(data);
  }

  Future<void> mergeSync(String text) async {
    final data = jsonDecode(text) as Map<String, dynamic>;
    await repository.importJson(
      text,
      includeUsage: data['platform'] == 'android',
      sync: true,
    );
    if (!device.supported &&
        data['platform'] == 'android' &&
        data['nativeNight'] is Map) {
      await repository.preference('pairedPhone', {
        'snapshot': data['nativeNight'],
        'at': data['exportedAt'],
      });
    }
    await reload();
    await refreshPhone();
  }

  Future<String> acceptSync(String text) async {
    // Serializes network imports with local edits.
    String? response;
    await run(() async {
      await mergeSync(text);
      response = await syncPayload();
    });
    if (response == null) throw StateError('Sync import failed');
    return response!;
  }

  Future<List<String>> hostSync() => sync.host(acceptSync);
  Future<void> joinSync(String code) => run(() async {
    final response = await LocalSync.exchange(code, await syncPayload());
    await mergeSync(response);
  });
  FocusController(this.repository, this.device);
  Future<void> initialize() async {
    await reload();
    await refreshPhone();
    await recoverSession();
    await syncNative();
    if (device.supported && phone['usageAccess'] == true) {
      unawaited(refreshUsage());
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = activeSession;
      if (s != null && !_finishing) {
        final end = DateTime.tryParse(s.data['targetEnd'] as String? ?? '');
        if (end != null && !end.isAfter(DateTime.now())) {
          _finishing = true;
          finishSession(
            completed: true,
            endedAt: end,
          ).whenComplete(() => _finishing = false);
        }
      }
      if (s != null) notifyListeners();
    });
  }

  void dismissError() {
    error = null;
    notifyListeners();
  }

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  Future<void> reload() async {
    entries = await repository.all();
    settings = await repository.preferences();
    usage = await repository.usage();
    notifyListeners();
  }

  Future<void> run(Future<void> Function() action) {
    final result = _pending.then((_) => _execute(action));
    _pending = result;
    return result;
  }

  Future<void> _execute(Future<void> Function() action) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      await reload();
      await syncNative();
    } catch (_) {
      error =
          'That change could not be saved. Your existing data is still available.';
      logEvent(LogLevel.error, 'operation_failed');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Iterable<Entry> of(String kind) =>
      entries.where((e) => e.kind == kind && !e.deleted);
  Entry? get activeSession {
    for (final e in of('session')) {
      if (e.state == 'active') return e;
    }
    return null;
  }

  Future<void> save(Entry e) => run(() => repository.save(e));
  Future<void> complete(Entry e) => run(() => repository.complete(e));
  Future<void> remove(Entry e) =>
      run(() => repository.save(e.copy(deleted: true)));
  Future<void> set(String key, Object? value) =>
      run(() => repository.preference(key, value));
  Future<void> startSession(
    int minutes,
    String? taskId, {
    bool isBreak = false,
  }) => run(() async {
    if (minutes < 0 || minutes > 240) throw ArgumentError('Invalid duration');
    if (activeSession != null) return;
    final now = DateTime.now().toUtc();
    Entry? task;
    for (final e in of('task')) {
      if (e.id == taskId) task = e;
    }
    await repository.save(
      Entry(
        kind: 'session',
        title: isBreak ? 'Rest and recharge' : task?.title ?? 'Deep work',
        state: 'active',
        projectId: task?.projectId,
        data: {
          'taskId': taskId,
          'isBreak': isBreak,
          'startedAt': now.toIso8601String(),
          'plannedSeconds': minutes * 60,
          'targetEnd': minutes == 0
              ? null
              : now.add(Duration(minutes: minutes)).toIso8601String(),
        },
      ),
    );
  });
  Future<void> finishSession({required bool completed, DateTime? endedAt}) =>
      run(() async {
        final s = activeSession;
        if (s == null) return;
        final start = DateTime.parse(s.data['startedAt'] as String);
        var end = (endedAt ?? DateTime.now()).toUtc();
        if (end.isBefore(start)) end = start;
        await repository.save(
          s.copy(
            state: completed ? 'completed' : 'interrupted',
            data: {
              ...s.data,
              'endedAt': end.toIso8601String(),
              'actualSeconds': end.difference(start).inSeconds,
              'interruptions': null,
            },
          ),
        );
        notice = completed
            ? (s.data['isBreak'] == true
                  ? 'Break complete. Ready for the next session?'
                  : 'Focus complete. Take a short break.')
            : 'Session saved.';
      });
  Future<void> toggleHabit(Entry habit) => run(() async {
    final days = Set<String>.from(habit.data['days'] as List? ?? []);
    final day = dayKey(DateTime.now());
    if (!days.add(day)) days.remove(day);
    await repository.save(
      habit.copy(data: {...habit.data, 'days': days.toList()..sort()}),
    );
  });
  Future<void> refreshPhone() async {
    try {
      phone = await device.status();
      if (!device.supported && settings['pairedPhone'] is Map) {
        final paired = settings['pairedPhone'] as Map;
        phone = {
          ...Map<String, dynamic>.from(paired['snapshot'] as Map),
          'supported': false,
          'syncedAt': paired['at'],
        };
      }
    } catch (_) {
      phone = {'supported': device.supported, 'state': 'unavailable'};
    }
    notifyListeners();
  }

  Future<void> configureNight(Map<String, dynamic> config) => run(() async {
    // Native commit is authoritative. A failed bridge call never reports enforcement enabled.
    await device.configure(config);
    for (final e in config.entries) {
      await repository.preference(e.key, e.value);
    }
    await refreshPhone();
  });
  Future<void> refreshUsage() => run(() async {
    await refreshPhone();
    if (phone['usageAccess'] != true) {
      throw StateError('Usage access unavailable');
    }
    final now = DateTime.now();
    // Replace each observed day idempotently. Historical OS retention is device-dependent.
    for (var i = 0; i < 7; i++) {
      final start = DateTime(now.year, now.month, now.day - i);
      final end = i == 0
          ? now
          : DateTime(start.year, start.month, start.day + 1);
      final rows = await device.usage(start, end);
      await repository.replaceUsageDay(dayKey(start), rows);
    }
  });
  Future<String> exportBackup() async {
    final backup = Map<String, dynamic>.from(
      jsonDecode(await repository.exportJson()) as Map,
    );
    await refreshPhone();
    backup['nativeNight'] = phone;
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  int get dailyFocusTarget =>
      (settings['focusTargetMinutes'] as num? ?? 240).toInt();
  int get phoneBudget =>
      (settings['phoneBudgetMinutes'] as num? ?? 210).toInt();
  @override
  void dispose() {
    _disposed = true;
    unawaited(sync.close());
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> syncNative() async {
    if (!device.supported) return;
    try {
      final s = activeSession;
      await device.focus(
        s?.data['isBreak'] == true ? null : s?.id,
        DateTime.tryParse(s?.data['targetEnd'] as String? ?? ''),
      );
      await device.discipline(disciplineRules);
      final now = DateTime.now();
      await device.events([
        if (s != null &&
            s.data['targetEnd'] != null &&
            DateTime.parse(s.data['targetEnd'] as String).isAfter(now))
          {
            'id': s.id,
            'at': DateTime.parse(
              s.data['targetEnd'] as String,
            ).millisecondsSinceEpoch,
            'title': s.data['isBreak'] == true
                ? 'Break completed'
                : 'Focus session completed',
            'body': 'Return to Focus when you are ready.',
            'focus': true,
          },
        for (final e
            in entries
                .where(
                  (e) =>
                      ['reminder', 'task', 'milestone'].contains(e.kind) &&
                      e.dueAt != null &&
                      e.dueAt!.isAfter(now) &&
                      !['completed', 'cancelled'].contains(e.state),
                )
                .take(499))
          {
            'id': e.id,
            'at': e.dueAt!.millisecondsSinceEpoch,
            'title': 'Focus reminder',
            'body': e.title,
          },
      ]);
    } catch (_) {
      notice =
          'Saved locally. Android scheduling could not be updated; reopen Focus to retry.';
    }
  }

  List<Map<String, dynamic>> get disciplineRules =>
      (settings['disciplineRules'] as List? ?? [])
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  Future<void> saveDiscipline(List<Map<String, dynamic>> rules) =>
      run(() async {
        await device.discipline(rules);
        await repository.preference('disciplineRules', rules);
      });
  Future<void> recoverSession() async {
    final s = activeSession;
    final end = DateTime.tryParse(s?.data['targetEnd'] as String? ?? '');
    if (end != null && !end.isAfter(DateTime.now())) {
      await finishSession(completed: true, endedAt: end);
    }
  }

  Future<void> resume() async {
    await refreshPhone();
    await recoverSession();
    await syncNative();
    if (device.supported && phone['usageAccess'] == true) {
      await refreshUsage();
    }
  }
}
