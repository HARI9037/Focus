import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus/app/controller.dart';
import 'package:focus/core/database/database.dart';
import 'package:focus/core/database/repository.dart';
import 'package:focus/core/platform/device_bridge.dart';
import 'package:focus/features/tasks/domain/entry.dart';
import 'package:focus/features/analytics/domain/analytics.dart';
import 'package:focus/features/analytics/domain/report.dart';

void main() {
  sqfliteFfiInit();
  late Database db;
  late LocalRepository repo;
  setUp(() async {
    db = await FocusDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      location: inMemoryDatabasePath,
    );
    repo = LocalRepository(db);
  });
  tearDown(() async {
    await db.close();
  });
  test('concurrent saves are queued, not silently dropped', () async {
    final c = FocusController(repo, DeviceBridge());
    await c.reload();
    addTearDown(c.dispose);
    await Future.wait([
      c.save(Entry(kind: 'task', title: 'One')),
      c.save(Entry(kind: 'task', title: 'Two')),
    ]);
    expect((await repo.all()).length, 2);
    expect(c.error, isNull);
  });
  test(
    'expired session restores once and breaks do not inflate focus',
    () async {
      final end = DateTime.now().subtract(const Duration(minutes: 1));
      await repo.save(
        Entry(
          kind: 'session',
          title: 'Break',
          state: 'active',
          data: {
            'isBreak': true,
            'startedAt': end
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
            'targetEnd': end.toIso8601String(),
          },
        ),
      );
      final c = FocusController(repo, DeviceBridge());
      await c.reload();
      addTearDown(c.dispose);
      await c.recoverSession();
      await c.recoverSession();
      expect(c.activeSession, isNull);
      expect(c.entries.single.data['actualSeconds'], 300);
      expect(
        AnalyticsEngine.focusSeconds(c.entries, DateTime(2000), DateTime.now()),
        0,
      );
    },
  );
  test('overwritten notes remain recoverable after sync', () async {
    final old = Entry(
      kind: 'note',
      title: 'Draft',
      body: 'Original',
      state: 'active',
      updatedAt: DateTime(2025),
    );
    await repo.save(old);
    final next = old.copy(body: 'Revised');
    await repo.importJson(
      jsonEncode({
        'format': 'focus-backup',
        'version': 1,
        'records': [next.toRow()],
      }),
      sync: true,
    );
    expect((await repo.all()).single.body, 'Revised');
    expect((await repo.versions(old.id)).single.body, 'Original');
  });
  test('backup restores previous note versions on a fresh database', () async {
    final note = Entry(
      kind: 'note',
      title: 'Draft',
      body: 'First',
      state: 'active',
      updatedAt: DateTime(2025),
    );
    await repo.save(note);
    await repo.save(note.copy(body: 'Second'));
    final backup = await repo.exportJson();
    await repo.deleteAll();
    await repo.importJson(backup);
    expect((await repo.all()).single.body, 'Second');
    expect((await repo.versions(note.id)).single.body, 'First');
  });
  test(
    'backup restores usage and targets while ignoring permission flags',
    () async {
      await repo.importJson(
        jsonEncode({
          'format': 'focus-backup',
          'version': 1,
          'records': [],
          'preferences': {
            'theme': 'dark',
            'focusTargetMinutes': 120,
            'enabled': true,
          },
          'usage': [
            {
              'day': '2026-09-01',
              'package': 'app.test',
              'label': 'Test',
              'milliseconds': 1000,
              'collected_at': '2026-09-01T12:00:00Z',
              'quality': 'estimate',
            },
          ],
        }),
        includeUsage: true,
        restoreSettings: true,
      );
      expect((await repo.preferences())['enabled'], isNull);
      expect((await repo.preferences())['focusTargetMinutes'], 120);
      expect((await repo.usage()).length, 1);
    },
  );
  test('invalid usage aborts before records are changed', () async {
    final e = Entry(kind: 'task', title: 'Should not save');
    await expectLater(
      repo.importJson(
        jsonEncode({
          'format': 'focus-backup',
          'version': 1,
          'records': [e.toRow()],
          'usage': [
            {'day': 'x'},
          ],
        }),
        includeUsage: true,
      ),
      throwsFormatException,
    );
    expect(await repo.all(), isEmpty);
  });
  test('schema v1 migrates without losing records', () async {
    final dir = await Directory.systemTemp.createTemp('focus-migration-');
    final file = '${dir.path}/test.db';
    final old = await databaseFactoryFfiNoIsolate.openDatabase(
      file,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final sql in FocusDatabase.schema.take(8)) {
            await db.execute(sql);
          }
        },
      ),
    );
    await LocalRepository(old).save(Entry(kind: 'task', title: 'Keep me'));
    await old.close();
    final migrated = await FocusDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      location: file,
    );
    expect((await LocalRepository(migrated).all()).single.title, 'Keep me');
    expect(await LocalRepository(migrated).versions('none'), isEmpty);
    await migrated.close();
    await dir.delete(recursive: true);
  });
  test('correlations need enough data and variation', () {
    expect(
      ReportEngine.correlation(
        List.generate(13, (i) => [i.toDouble(), i.toDouble()]),
      ),
      isNull,
    );
    expect(ReportEngine.correlation(List.generate(14, (i) => [1, 1])), isNull);
    expect(
      ReportEngine.correlation(
        List.generate(14, (i) => [i.toDouble(), -i.toDouble()]),
      ),
      closeTo(-1, 0.00001),
    );
  });
}
