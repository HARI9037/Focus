import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../features/tasks/domain/entry.dart';

abstract interface class EntryRepository {
  Future<List<Entry>> all();
  Future<void> save(Entry entry);
  Future<void> complete(Entry entry);
}

class LocalRepository implements EntryRepository {
  final Database db;
  LocalRepository(this.db);
  @override
  Future<List<Entry>> all() async => (await db.query(
    'records',
    where: 'deleted=0',
    orderBy: 'priority DESC, created_at DESC',
  )).map(Entry.fromRow).toList();
  @override
  Future<void> save(Entry entry) async {
    validateEntry(entry);
    await db.transaction((tx) async {
      final old = await tx.query(
        'records',
        where: 'id=?',
        whereArgs: [entry.id],
      );
      if (old.isNotEmpty) {
        await _preserveVersion(tx, Entry.fromRow(old.first), entry);
      }
      await tx.insert(
        'records',
        entry.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _preserveVersion(
    DatabaseExecutor tx,
    Entry old,
    Entry next,
  ) async {
    if (!['note', 'idea'].contains(old.kind) ||
        old.deleted ||
        next.deleted ||
        old.body == next.body && old.title == next.title) {
      return;
    }
    await tx.insert('record_versions', {
      'record_id': old.id,
      'updated_at': old.updatedAt.toIso8601String(),
      'payload': jsonEncode(old.toRow()),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await tx.rawDelete(
      'DELETE FROM record_versions WHERE record_id=? AND updated_at NOT IN (SELECT updated_at FROM record_versions WHERE record_id=? ORDER BY updated_at DESC LIMIT 20)',
      [old.id, old.id],
    );
  }

  Future<List<Entry>> versions(String id) async =>
      (await db.query(
            'record_versions',
            where: 'record_id=?',
            whereArgs: [id],
            orderBy: 'updated_at DESC',
          ))
          .map(
            (r) => Entry.fromRow(
              Map<String, Object?>.from(
                jsonDecode(r['payload'] as String) as Map,
              ),
            ),
          )
          .toList();

  @override
  Future<void> complete(Entry entry) async {
    await db.transaction((tx) async {
      final current = await tx.query(
        'records',
        where: 'id=? AND deleted=0',
        whereArgs: [entry.id],
      );
      if (current.isEmpty) return;
      final e = Entry.fromRow(current.first);
      if (e.state == 'completed') {
        return; // Idempotent: cannot spawn duplicate recurrences.
      }
      await tx.update(
        'records',
        e
            .copy(
              state: 'completed',
              data: {
                ...e.data,
                'completedAt': DateTime.now().toUtc().toIso8601String(),
              },
            )
            .toRow(),
        where: 'id=?',
        whereArgs: [e.id],
      );
      final next = nextOccurrence(
        e.dueAt ?? DateTime.now(),
        e.data['recurrence'] as String? ?? 'none',
      );
      if (e.kind == 'task' && next != null) {
        await tx.insert(
          'records',
          Entry(
            kind: 'task',
            title: e.title,
            body: e.body,
            state: 'planned',
            priority: e.priority,
            projectId: e.projectId,
            dueAt: next,
            data: {...e.data}..remove('completedAt'),
          ).toRow(),
        );
      }
    });
  }

  Future<Map<String, dynamic>> preferences() async => {
    for (final r in await db.query('preferences'))
      r['key'] as String: jsonDecode(r['value'] as String),
  };
  Future<void> preference(String key, Object? value) async {
    await db.insert('preferences', {
      'key': key,
      'value': jsonEncode(value),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> replaceUsageDay(
    String day,
    List<Map<String, dynamic>> rows,
  ) async {
    await db.transaction((tx) async {
      await tx.delete('usage_daily', where: 'day=?', whereArgs: [day]);
      for (final row in rows) {
        await tx.insert('usage_daily', {
          'day': day,
          'package': row['package'],
          'label': row['label'],
          'milliseconds': row['milliseconds'],
          'collected_at': DateTime.now().toUtc().toIso8601String(),
          'quality': 'android_usage_stats_estimate',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<Map<String, Object?>>> usage() =>
      db.query('usage_daily', orderBy: 'day, milliseconds DESC');
  Future<String> exportJson() async =>
      const JsonEncoder.withIndent('  ').convert({
        'format': 'focus-backup',
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'records': await db.query('records'),
        'noteVersions': await db.query('record_versions'),
        'usage': await usage(),
        'preferences': await preferences(),
      });
  Future<void> importJson(
    String source, {
    bool includeUsage = false,
    bool restoreSettings = false,
    bool sync = false,
  }) async {
    if (source.length > 20 * 1024 * 1024) {
      throw const FormatException('Backup exceeds 20 MB');
    }
    final json = jsonDecode(source);
    if (json is! Map ||
        json['format'] != 'focus-backup' ||
        json['version'] != 1 ||
        json['records'] is! List) {
      throw const FormatException('Unsupported Focus backup');
    }
    final records = (json['records'] as List)
        .map((r) => Entry.fromRow(Map<String, Object?>.from(r as Map)))
        .toList();
    const kinds = {
      'task',
      'project',
      'note',
      'idea',
      'reminder',
      'goal',
      'habit',
      'session',
      'override',
      'milestone',
    };
    for (final e in records) {
      validateEntry(e);
      if (!kinds.contains(e.kind) ||
          e.title.trim().isEmpty ||
          e.priority < 0 ||
          e.priority > 3) {
        throw const FormatException('Invalid record');
      }
    }
    final usageRows = includeUsage
        ? List<Map<String, Object?>>.from(
            (json['usage'] as List? ?? []).map(
              (r) => Map<String, Object?>.from(r as Map),
            ),
          )
        : <Map<String, Object?>>[];
    for (final r in usageRows) {
      if (r['day'] is! String ||
          DateTime.tryParse(r['day'] as String) == null ||
          r['package'] is! String ||
          r['label'] is! String ||
          r['milliseconds'] is! int ||
          (r['milliseconds'] as int) < 0 ||
          (r['milliseconds'] as int) > 172800000 ||
          r['collected_at'] is! String ||
          DateTime.tryParse(r['collected_at'] as String) == null ||
          r['quality'] is! String) {
        throw const FormatException('Invalid usage row');
      }
    }
    final incomingSettings = Map<String, dynamic>.from(
      json['preferences'] as Map? ?? {},
    );
    final versions = (json['noteVersions'] as List? ?? []).map((row) {
      final e = Entry.fromRow(
        Map<String, Object?>.from(jsonDecode(row['payload'] as String) as Map),
      );
      validateEntry(e);
      if (!['note', 'idea'].contains(e.kind) ||
          e.id != row['record_id'] ||
          e.deleted) {
        throw const FormatException('Invalid note version');
      }
      return e;
    }).toList();
    if (restoreSettings) {
      for (final key in ['phoneBudgetMinutes', 'focusTargetMinutes']) {
        final n = incomingSettings[key];
        if (n != null && (n is! int || n < 1 || n > 1440)) {
          throw const FormatException('Invalid target');
        }
      }
      if (incomingSettings['theme'] != null &&
          !['system', 'dark', 'light'].contains(incomingSettings['theme'])) {
        throw const FormatException('Invalid theme');
      }
    }
    // Device permissions and live sessions are never enabled by a sync import.
    await db.transaction((tx) async {
      for (final e in records) {
        if (sync && e.kind == 'session' && e.state == 'active') continue;
        final existing = await tx.query(
          'records',
          where: 'id=?',
          whereArgs: [e.id],
        );
        final old = existing.isEmpty ? null : Entry.fromRow(existing.first);
        if (old == null ||
            e.updatedAt.isAfter(old.updatedAt) ||
            e.updatedAt.isAtSameMomentAs(old.updatedAt) &&
                jsonEncode(e.toRow()).compareTo(jsonEncode(old.toRow())) > 0) {
          if (existing.isNotEmpty) {
            await _preserveVersion(tx, Entry.fromRow(existing.first), e);
          }
          await tx.insert(
            'records',
            e.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else if (existing.isNotEmpty) {
          await _preserveVersion(tx, e, Entry.fromRow(existing.first));
        }
      }
      for (final e in versions) {
        await tx.insert('record_versions', {
          'record_id': e.id,
          'updated_at': e.updatedAt.toIso8601String(),
          'payload': jsonEncode(e.toRow()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final id in versions.map((e) => e.id).toSet()) {
        await tx.rawDelete(
          'DELETE FROM record_versions WHERE record_id=? AND updated_at NOT IN (SELECT updated_at FROM record_versions WHERE record_id=? ORDER BY updated_at DESC LIMIT 20)',
          [id, id],
        );
      }
      for (final r in usageRows) {
        final existing = await tx.query(
          'usage_daily',
          where: 'day=? AND package=?',
          whereArgs: [r['day'], r['package']],
        );
        if (existing.isEmpty ||
            DateTime.parse(r['collected_at'] as String).isAfter(
              DateTime.parse(existing.first['collected_at'] as String),
            )) {
          await tx.insert(
            'usage_daily',
            r,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      if (restoreSettings) {
        for (final key in [
          'theme',
          'phoneBudgetMinutes',
          'focusTargetMinutes',
        ]) {
          if (incomingSettings.containsKey(key)) {
            await tx.insert('preferences', {
              'key': key,
              'value': jsonEncode(incomingSettings[key]),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });
  }

  Future<void> deleteAll() async {
    await db.transaction((tx) async {
      await tx.delete('usage_daily');
      await tx.delete('records');
      await tx.delete('preferences');
      await tx.delete('record_versions');
    });
  }

  Future<String> exportCsv() async {
    String cell(Object? value) {
      var s = '${value ?? ''}';
      if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }

    final rows = await db.query('records', where: 'deleted=0');
    const keys = [
      'id',
      'kind',
      'title',
      'state',
      'priority',
      'due_at',
      'project_id',
      'created_at',
    ];
    return [
      keys.join(','),
      ...rows.map((r) => keys.map((k) => cell(r[k])).join(',')),
    ].join('\r\n');
  }
}
