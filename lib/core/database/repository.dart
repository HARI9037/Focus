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
  @override Future<List<Entry>> all() async =>
    (await db.query('records', where: 'deleted=0', orderBy: 'priority DESC, created_at DESC'))
      .map(Entry.fromRow).toList();
  @override Future<void> save(Entry entry) async {
    validateEntry(entry);
    await db.insert('records', entry.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
  @override Future<void> complete(Entry entry) async {
    await db.transaction((tx) async {
      final current = await tx.query('records', where: 'id=? AND deleted=0', whereArgs: [entry.id]);
      if (current.isEmpty) return;
      final e = Entry.fromRow(current.first);
      if (e.state == 'completed') return; // Idempotent: cannot spawn duplicate recurrences.
      await tx.update('records', e.copy(state: 'completed', data: {
        ...e.data, 'completedAt': DateTime.now().toUtc().toIso8601String(),
      }).toRow(), where: 'id=?', whereArgs: [e.id]);
      final next = nextOccurrence(e.dueAt ?? DateTime.now(), e.data['recurrence'] as String? ?? 'none');
      if (e.kind == 'task' && next != null) {
        await tx.insert('records', Entry(kind: 'task', title: e.title, body: e.body,
          state: 'planned', priority: e.priority, projectId: e.projectId, dueAt: next,
          data: {...e.data}..remove('completedAt')).toRow());
      }
    });
  }
  Future<Map<String, dynamic>> preferences() async => {
    for (final r in await db.query('preferences'))
      r['key'] as String: jsonDecode(r['value'] as String)
  };
  Future<void> preference(String key, Object? value) async {
    await db.insert('preferences', {'key': key, 'value': jsonEncode(value)},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }
  Future<void> replaceUsageDay(String day, List<Map<String, dynamic>> rows) async {
    await db.transaction((tx) async {
      await tx.delete('usage_daily', where: 'day=?', whereArgs: [day]);
      for (final row in rows) {
        await tx.insert('usage_daily', {'day': day, 'package': row['package'],
          'label': row['label'], 'milliseconds': row['milliseconds'],
          'collected_at': DateTime.now().toUtc().toIso8601String(),
          'quality': 'android_usage_stats_estimate'}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
  Future<List<Map<String, Object?>>> usage() => db.query('usage_daily', orderBy: 'day, milliseconds DESC');
  Future<String> exportJson() async => const JsonEncoder.withIndent('  ').convert({
    'format': 'focus-backup', 'version': 1, 'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'records': await db.query('records'), 'usage': await usage(),
    'preferences': await preferences(),
  });
  Future<void> importJson(String source) async {
    if (source.length > 20 * 1024 * 1024) throw const FormatException('Backup exceeds 20 MB');
    final json = jsonDecode(source);
    if (json is! Map || json['format'] != 'focus-backup' || json['version'] != 1 || json['records'] is! List) {
      throw const FormatException('Unsupported Focus backup');
    }
    final records = (json['records'] as List).map((r) => Entry.fromRow(Map<String,Object?>.from(r as Map))).toList();
    const kinds = {'task','project','note','idea','reminder','goal','habit','session','override'};
    for (final e in records) {
      validateEntry(e);
      if (!kinds.contains(e.kind) || e.title.trim().isEmpty || e.priority < 0 || e.priority > 3) {
        throw const FormatException('Invalid record');
      }
    }
    // Merge by ID/updated timestamp, including tombstones; never enables permissions or Night Lock.
    await db.transaction((tx) async {
      for (final e in records) {
        final existing = await tx.query('records', where: 'id=?', whereArgs: [e.id]);
        if (existing.isEmpty || e.updatedAt.isAfter(Entry.fromRow(existing.first).updatedAt)) {
          await tx.insert('records', e.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
  Future<String> exportCsv() async {
    String cell(Object? value) {
      var s = '${value ?? ''}';
      if (RegExp(r'^[=+\-@\t\r]').hasMatch(s)) s = "'$s";
      return '"${s.replaceAll('"', '""')}"';
    }
    final rows = await db.query('records', where: 'deleted=0');
    const keys = ['id','kind','title','state','priority','due_at','project_id','created_at'];
    return [keys.join(','), ...rows.map((r) => keys.map((k) => cell(r[k])).join(','))].join('\r\n');
  }
}
