import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus/app/controller.dart';
import 'package:focus/app/editor.dart';
import 'package:focus/app/screens.dart';
import 'package:focus/core/database/database.dart';
import 'package:focus/core/database/repository.dart';
import 'package:focus/core/platform/device_bridge.dart';
import 'package:focus/features/tasks/domain/entry.dart';

void main() {
  sqfliteFfiInit();
  for (final kind in [
    'task',
    'project',
    'milestone',
    'note',
    'idea',
    'reminder',
    'goal',
    'habit',
  ]) {
    testWidgets('capture $kind on a narrow display', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = await FocusDatabase.open(
        factory: databaseFactoryFfiNoIsolate,
        location: inMemoryDatabasePath,
      );
      final c = FocusController(LocalRepository(db), DeviceBridge());
      await c.reload();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => editEntry(context, c, kind: kind),
                child: const Text('Capture'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Capture'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'),
        'New $kind',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(c.error, isNull);
      expect(c.entries.single.kind, kind);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
      await db.close();
    });
  }
  testWidgets('milestones appear in task, project and search results', (
    tester,
  ) async {
    final db = await FocusDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      location: inMemoryDatabasePath,
    );
    final c = FocusController(LocalRepository(db), DeviceBridge());
    final project = Entry(kind: 'project', title: 'Release', state: 'active');
    await c.repository.save(project);
    await c.repository.save(
      Entry(kind: 'milestone', title: 'Ship milestone', projectId: project.id),
    );
    await c.reload();
    for (final page in <Widget>[
      RecordsScreen(c: c, kind: 'task'),
      RecordsScreen(c: c, kind: 'project'),
      SearchScreen(c: c, query: 'Ship'),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      await tester.pumpAndSettle();
      expect(find.text('Ship milestone'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await db.close();
  });
}
