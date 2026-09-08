import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FocusDatabase {
  static const version = 1;
  static const schema = <String>[
    """CREATE TABLE records (
      id TEXT PRIMARY KEY, kind TEXT NOT NULL, title TEXT NOT NULL,
      body TEXT NOT NULL DEFAULT '', state TEXT NOT NULL,
      priority INTEGER NOT NULL CHECK(priority BETWEEN 0 AND 3),
      project_id TEXT, due_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
      deleted INTEGER NOT NULL DEFAULT 0 CHECK(deleted IN (0,1)), data TEXT NOT NULL)""",
    'CREATE INDEX records_kind_state ON records(kind,deleted,state)',
    'CREATE INDEX records_due ON records(due_at) WHERE deleted=0',
    'CREATE INDEX records_project ON records(project_id) WHERE deleted=0',
    'CREATE INDEX records_updated ON records(updated_at)',
    'CREATE TABLE preferences (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    """CREATE TABLE usage_daily (
      day TEXT NOT NULL, package TEXT NOT NULL, label TEXT NOT NULL,
      milliseconds INTEGER NOT NULL CHECK(milliseconds>=0),
      collected_at TEXT NOT NULL, quality TEXT NOT NULL,
      PRIMARY KEY(day,package))""",
    'CREATE INDEX usage_day ON usage_daily(day)',
  ];
  static Future<Database> open({DatabaseFactory? factory, String? location}) async {
    if (factory == null && Platform.isWindows) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    factory ??= databaseFactory;
    final file = location ?? path.join((await getApplicationSupportDirectory()).path, 'focus.db');
    return factory.openDatabase(file, options: OpenDatabaseOptions(
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys=ON');
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
      onCreate: (db, _) async { for (final sql in schema) { await db.execute(sql); } },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Each future version must add a forward-only transactional migration.
        throw StateError('No migration from $oldVersion to $newVersion');
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        throw StateError('This data needs a newer version of Focus.');
      },
    ));
  }
}
