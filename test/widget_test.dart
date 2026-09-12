import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:focus/app/controller.dart';
import 'package:focus/app/focus_app.dart';
import 'package:focus/core/database/database.dart';
import 'package:focus/core/database/repository.dart';
import 'package:focus/core/platform/device_bridge.dart';

void main() {
  sqfliteFfiInit();
  testWidgets('desktop quick capture persists a task', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = await FocusDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      location: inMemoryDatabasePath,
    );
    final repository = LocalRepository(db);
    await repository.preference('onboarded', true);
    final c = FocusController(repository, DeviceBridge());
    await c.reload();
    await tester.pumpWidget(FocusApp(controller: c));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quick capture (Ctrl+N)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Read chapter 4',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect((await repository.all()).single.title, 'Read chapter 4');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await db.close();
  });
  testWidgets('mobile onboarding fits a small display', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = await FocusDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      location: inMemoryDatabasePath,
    );
    final c = FocusController(LocalRepository(db), DeviceBridge());
    await c.reload();
    await tester.pumpWidget(FocusApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('Take back control\nof your attention.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await db.close();
  });
}
