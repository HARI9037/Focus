import 'package:flutter/material.dart';
import 'app/controller.dart';
import 'app/focus_app.dart';
import 'core/database/database.dart';
import 'core/database/repository.dart';
import 'core/platform/device_bridge.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await FocusDatabase.open();
    final controller = FocusController(
      LocalRepository(database),
      DeviceBridge(),
    );
    await controller.initialize();
    runApp(FocusApp(controller: controller));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_outlined, size: 48),
                  const SizedBox(height: 24),
                  const Text(
                    'Focus could not open your local data.',
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Your database has not been reset. Free some device storage, then restart Focus.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => DeviceBridge().emergency(),
                    child: const Text('Open phone / emergency access'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
