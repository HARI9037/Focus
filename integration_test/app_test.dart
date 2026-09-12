import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:focus/app/controller.dart';
import 'package:focus/app/focus_app.dart';
import 'package:focus/core/database/database.dart';
import 'package:focus/core/database/repository.dart';
import 'package:focus/core/platform/device_bridge.dart';

class ReadOnlyBridge extends DeviceBridge {
  @override
  Future<void> discipline(List<Map<String, dynamic>> rules) async {}
  @override
  Future<void> focus(String? id, DateTime? end) async {}
  @override
  Future<void> events(List<Map<String, dynamic>> events) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native database survives reopen and quick capture works', (
    tester,
  ) async {
    // A separate test database never touches the user's focus.db.
    final directory = await getTemporaryDirectory();
    final location =
        '${directory.path}/focus-runtime-${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await FocusDatabase.open(location: location);
    final repository = LocalRepository(db);
    await repository.preference('onboarded', true);
    final bridge = ReadOnlyBridge();
    final controller = FocusController(repository, bridge);
    await controller.reload();
    final status = await bridge.status();
    expect(status['supported'], Platform.isAndroid);
    if (Platform.isAndroid) {
      expect(status['usageAccess'], isA<bool>());
      expect(status['accessibility'], isA<bool>());
      expect(await bridge.apps(), isNotEmpty);
    }
    await tester.pumpWidget(FocusApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Quick capture (Ctrl+N)'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Runtime persistence check',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(controller.error, isNull);
    expect(controller.entries.single.title, 'Runtime persistence check');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await db.close();
    final reopened = await FocusDatabase.open(location: location);
    expect(
      (await LocalRepository(reopened).all()).single.title,
      'Runtime persistence check',
    );
    await reopened.close();
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File('$location$suffix');
      if (await file.exists()) await file.delete();
    }
  });
}
