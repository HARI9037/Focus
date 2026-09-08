import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/database/repository.dart';
import '../core/logging/log.dart';
import '../core/platform/device_bridge.dart';
import '../features/tasks/domain/entry.dart';

class FocusController extends ChangeNotifier {
  final LocalRepository repository;
  final DeviceBridge device;
  List<Entry> entries = [];
  List<Map<String,Object?>> usage = [];
  Map<String,dynamic> settings = {}, phone = {};
  String? error;
  bool busy = false;
  Timer? _ticker;
  bool _finishing = false;
  FocusController(this.repository, this.device);
  Future<void> initialize() async {
    await reload();
    await refreshPhone();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = activeSession;
      if (s != null && !_finishing) {
        final end = DateTime.tryParse(s.data['targetEnd'] as String? ?? '');
        if (end != null && !end.isAfter(DateTime.now())) {
          _finishing = true;
          finishSession(completed: true, endedAt: end).whenComplete(() => _finishing = false);
        }
      }
      notifyListeners();
    });
  }
  void dismissError() { error = null; notifyListeners(); }
  Future<void> reload() async {
    entries = await repository.all();
    settings = await repository.preferences();
    usage = await repository.usage();
    notifyListeners();
  }
  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    busy = true; error = null; notifyListeners();
    try { await action(); await reload(); }
    catch (_) { error = 'That change could not be saved. Your existing data is still available.'; logEvent(LogLevel.error,'operation_failed'); }
    finally { busy = false; notifyListeners(); }
  }
  Iterable<Entry> of(String kind) => entries.where((e) => e.kind == kind && !e.deleted);
  Entry? get activeSession {
    for (final e in of('session')) { if (e.state == 'active') return e; }
    return null;
  }
  Future<void> save(Entry e) => run(() => repository.save(e));
  Future<void> complete(Entry e) => run(() => repository.complete(e));
  Future<void> remove(Entry e) => run(() => repository.save(e.copy(deleted:true)));
  Future<void> set(String key, Object? value) => run(() => repository.preference(key,value));
  Future<void> startSession(int minutes, String? taskId) => run(() async {
    if (activeSession != null) return;
    final now = DateTime.now().toUtc();
    Entry? task;
    for (final e in of('task')) { if (e.id == taskId) task = e; }
    await repository.save(Entry(kind:'session',title:task?.title ?? 'Deep work',state:'active',
      projectId:task?.projectId,data:{'taskId':taskId,'startedAt':now.toIso8601String(),
        'plannedSeconds':minutes*60,'targetEnd':minutes == 0 ? null : now.add(Duration(minutes:minutes)).toIso8601String()}));
  });
  Future<void> finishSession({required bool completed, DateTime? endedAt}) => run(() async {
    final s = activeSession;
    if (s == null) return;
    final start = DateTime.parse(s.data['startedAt'] as String);
    var end = (endedAt ?? DateTime.now()).toUtc();
    if (end.isBefore(start)) end = start;
    await repository.save(s.copy(state:completed ? 'completed' : 'interrupted',data:{...s.data,
      'endedAt':end.toIso8601String(),'actualSeconds':end.difference(start).inSeconds,
      'interruptions':null}));
  });
  Future<void> toggleHabit(Entry habit) => run(() async {
    final days = Set<String>.from(habit.data['days'] as List? ?? []);
    final day = dayKey(DateTime.now());
    if (!days.add(day)) days.remove(day);
    await repository.save(habit.copy(data:{...habit.data,'days':days.toList()..sort()}));
  });
  Future<void> refreshPhone() async {
    try { phone = await device.status(); }
    catch (_) { phone = {'supported':device.supported, 'state':'unavailable'}; }
    notifyListeners();
  }
  Future<void> configureNight(Map<String,dynamic> config) => run(() async {
    // Native commit is authoritative. A failed bridge call never reports enforcement enabled.
    await device.configure(config);
    for (final e in config.entries) { await repository.preference(e.key,e.value); }
    await refreshPhone();
  });
  Future<void> refreshUsage() => run(() async {
    await refreshPhone();
    if (phone['usageAccess'] != true) throw StateError('Usage access unavailable');
    final now = DateTime.now();
    // Replace each observed day idempotently. Historical OS retention is device-dependent.
    for (var i = 0; i < 7; i++) {
      final start = DateTime(now.year,now.month,now.day-i);
      final end = i == 0 ? now : DateTime(start.year,start.month,start.day+1);
      final rows = await device.usage(start,end);
      if (rows.isNotEmpty) await repository.replaceUsageDay(dayKey(start),rows);
    }
  });
  Future<String> exportBackup() async {
    final backup = Map<String,dynamic>.from(jsonDecode(await repository.exportJson()) as Map);
    await refreshPhone();
    backup['nativeNight'] = phone;
    return const JsonEncoder.withIndent('  ').convert(backup);
  }
  int get dailyFocusTarget => (settings['focusTargetMinutes'] as num? ?? 240).toInt();
  int get phoneBudget => (settings['phoneBudgetMinutes'] as num? ?? 210).toInt();
  @override void dispose() { _ticker?.cancel(); super.dispose(); }
}
