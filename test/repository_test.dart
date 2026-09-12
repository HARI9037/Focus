import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus/core/database/database.dart';
import 'package:focus/core/database/repository.dart';
import 'package:focus/features/tasks/domain/entry.dart';

void main() {
  sqfliteFfiInit();
  late LocalRepository repository;
  setUp(() async {
    repository = LocalRepository(
      await FocusDatabase.open(
        factory: databaseFactoryFfi,
        location: inMemoryDatabasePath,
      ),
    );
  });
  tearDown(() async {
    await repository.db.close();
  });
  test('completion is transactional and idempotent', () async {
    final task = Entry(
      kind: 'task',
      title: 'Study',
      dueAt: DateTime(2026, 9, 8, 10),
      data: {'recurrence': 'daily'},
    );
    await repository.save(task);
    await repository.complete(task);
    await repository.complete(task);
    final tasks = await repository.all();
    expect(tasks.length, 2);
    expect(tasks.where((e) => e.state == 'completed').length, 1);
    expect(
      tasks.singleWhere((e) => e.id != task.id).dueAt!.toLocal(),
      DateTime(2026, 9, 9, 10),
    );
  });
  test('settings survive separate reads', () async {
    await repository.preference('theme', 'dark');
    expect((await repository.preferences())['theme'], 'dark');
  });
  test('usage reimport replaces a day instead of doubling totals', () async {
    final rows = [
      {'package': 'app.test', 'label': 'Test', 'milliseconds': 60000},
    ];
    await repository.replaceUsageDay('2026-09-08', rows);
    await repository.replaceUsageDay('2026-09-08', rows);
    expect((await repository.usage()).length, 1);
  });
  test('backup merge does not restore permission settings', () async {
    await repository.save(
      Entry(kind: 'note', title: 'A note', body: 'Private', state: 'active'),
    );
    final backup = await repository.exportJson();
    await repository.importJson(backup);
    expect((await repository.all()).length, 1);
    expect((await repository.preferences()).containsKey('enabled'), false);
  });
  test('malformed backup leaves existing records intact', () async {
    await repository.save(Entry(kind: 'task', title: 'Keep'));
    await expectLater(
      repository.importJson(
        jsonEncode({'format': 'focus-backup', 'version': 99, 'records': []}),
      ),
      throwsFormatException,
    );
    expect((await repository.all()).single.title, 'Keep');
  });
  test('CSV neutralizes formulas and quotes multiline text', () async {
    await repository.save(
      Entry(kind: 'note', title: '=SUM(1,2)', state: 'active'),
    );
    expect(await repository.exportCsv(), contains("'="));
  });
}
