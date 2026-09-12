# Focus 0.2

Local productivity for Android and Windows, with voluntary Android restrictions and encrypted local-network sync. No account, cloud service or AI is required.

Both platforms now compile. Windows passed a native runtime persistence test. See [implementation status](docs/STATUS.md) and [verification evidence](docs/VALIDATION.md) for the precise scope and remaining acceptance work.

## Build

Use Flutter **3.41.4**, Java 17, Android SDK, Python 3.9+, and Visual Studio's **Desktop development with C++** workload for Windows. Keep pubspec.lock.

```powershell
python tools/bootstrap.py
flutter analyze
flutter test
flutter run -d windows
```

Bootstrap applies canonical Android code from native/android to android and resolves packages. Existing complete runners are preserved; back up custom runner changes before using --refresh-runners. First builds need dependency downloads. Normal use works offline.

```powershell
./tools/build-android.ps1
./tools/build-windows.ps1
./tools/package-release.ps1
```

The Android script prepares or retains a private signing identity and builds app-release.apk. Windows output is the complete build/windows/x64/runner/Release folder. Packaging writes distributable files to dist. Keep all Windows DLLs and its data folder together.

Back up android/focus-release.jks and android/key.properties privately. Never commit them or share PRIVATE-signing-recovery.zip. Losing that key prevents compatible Android updates. Debug APKs use a different signature; do not uninstall an existing app with data merely to bypass a signature mismatch.

## Use

- Capture tasks, milestones, projects, notes, ideas, reminders, goals and habits with **+** or **Ctrl+N**. Use **Ctrl+K** for Windows search.
- Focus sessions offer presets, custom/open-ended timers, breaks, task association and restart recovery.
- On Android, read the Settings permission disclosures and configure Usage Access, the optional Restriction service, notifications and exact alarms as needed. Choose essential apps before enabling Night Lock.
- Digital discipline provides shared daily app/category budgets, warnings, focus blocking and cooldowns.
- Device sync works on a private local network. Start pairing on one device and enter its temporary code on the other. Pairing expires after ten minutes. Sync is manual. Android usage/status become dated Windows snapshots; previous note revisions stay recoverable.
- Settings exports JSON backups and CSV. JSON restore merges records, usage and note history, and restores appearance/daily targets. Permissions and restrictions remain under your control.

Night Lock defaults to 21:00–07:00 and stays disabled until enabled. Immediate emergency escape and Android safety settings remain reachable. Android may stop services or delay alarms. Complete the [device checks](docs/DEVICE_TESTS.md) before relying on overnight restrictions.

## Verify

```powershell
python tools/check_native.py
python tools/check_source.py
flutter analyze
flutter test
flutter test integration_test/app_test.dart -d windows
flutter test integration_test/app_test.dart -d YOUR_TEST_EMULATOR
```

Integration tests use a separate temporary database and avoid changing restrictions. Use a test emulator: instrumentation installs a test build under the app package. GitHub Actions builds both platforms and uploads development artifacts; private signing keys stay local.

The OS application directory holds local data. The database and exported backups are not independently encrypted. LAN sync traffic is encrypted. No telemetry or external AI service is included. Optional AI, automatic background sync, closed-app Windows reminders, richer usage measurements, encryption at rest and full production acceptance remain future work.

