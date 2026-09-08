# Focus

**A native Flutter source implementation for personal productivity on Android and Windows.**

Development release **0.1.0**. This is a substantial initial implementation, **not a finished production app or a compiled APK**. Flutter and Android SDKs were unavailable in the authoring environment and SDK downloads could not be reached. The actual Java scheduling and usage engines and the SQLite schema were checked locally; the Flutter/Kotlin application has not been compiled, visually inspected, or tested on a phone. No screenshots or fabricated activity are included.

## Start on your Windows laptop

Install these prerequisites using their official installers:

1. [Flutter SDK](https://docs.flutter.dev/install) — the included CI recipe targets Flutter 3.35.7 / Dart 3.9. Use that version for the first reproducible build.
2. [Android Studio](https://developer.android.com/studio), its Android SDK, and Java 17 for Android builds. Accept SDK licenses using `flutter doctor --android-licenses`.
3. [Visual Studio](https://docs.flutter.dev/platform-integration/windows/setup) with **Desktop development with C++**, its Windows SDK and CMake tools for Windows builds. Visual Studio Code alone does not provide the Windows compiler.
4. Python 3.9+ to generate the official platform runners.

Extract this archive, open a terminal in the `Focus` folder, and run:

```powershell
flutter doctor -v
python tools/bootstrap.py
flutter analyze --no-fatal-infos
flutter test
flutter run -d windows
```

`bootstrap.py` generates Flutter's official Android and Windows runner projects in a temporary directory, copies them here, and applies `native/android`. Your application code and tests are preserved. A first build needs Internet access for Flutter packages and Gradle dependencies. The application itself is local and works offline.

The canonical Android integration lives in `native/android`; after bootstrap, its applied copy lives in `android`. Make future native changes in `native/android` and apply them to `android` before building. The script refuses to overwrite existing runners unless `--refresh-runners` is explicitly supplied; back up custom runner edits first.

No dependency lockfile is invented. After the first successful `flutter pub get`, retain and commit the generated `pubspec.lock` and runner metadata. Selected SQLite dependencies are pinned to the Dart 3.9 compatible line. `sqlite3_flutter_libs` bundles the native SQLite library for Windows release builds; verify the DLL is in the final distribution.

## Build for your phone

Enable USB debugging on your Android device, connect it, then:

```powershell
flutter devices
flutter run -d YOUR_ANDROID_DEVICE_ID
flutter build apk --debug
```

The **development APK** will be at `build/app/outputs/flutter-apk/app-debug.apk` after a successful build. It uses development signing and is not a store release. No APK was generated in this authoring environment.

To produce a Windows distribution:

```powershell
flutter build windows --release
```

Keep the entire `build/windows/x64/runner/Release` folder together, including native DLLs and the `data` directory. Installer packaging and production Android signing remain release work.

PowerShell wrappers are in `tools/`. A GitHub Actions workflow is supplied, but it has **not** been uploaded, triggered, or verified. Putting the source in your own repository is a separate action.

## What is in the source

| Area | Implemented source behavior |
| --- | --- |
| First run and design | Four-step onboarding; dark, light and system themes; responsive sidebar and mobile navigation; no seeded activity |
| Today and inbox | Priority list, capture, recorded focus progress, due items, clearly unavailable phone metrics |
| Tasks | Create, edit, complete, delete; statuses, priorities, project, tags, due date/time, estimate; daily, weekly and monthly recurrence |
| Projects | Create/edit projects, link tasks, derive task completion progress |
| Notes and ideas | Plain Markdown text, tags, project association, pins, search |
| Calendar | Day/week/month agenda ranges for due items and focus sessions |
| Focus | 25/50/90-minute presets, custom 1–240-minute timer, open-ended sessions, task links, history and persisted restart recovery |
| Goals and habits | Manually updated goals; daily habit check-ins, current and longest streak |
| Analytics | Recorded focus charts with tooltips, app usage totals, 1/7/30-day views, transparent productivity and discipline components |
| Android Night Lock | Persisted native schedule, 21:00–07:00 default, opt-in accessibility overlay, exact/inexact alarms, warnings, recovery receiver, essential-app list, ordinary override friction and immediate emergency escape |
| Android usage | On-demand UsageEvents replay, bounded lookback, daily foreground estimates in SQLite; no continuous UsageStats polling |
| Data | SQLite repository, schema version and indexes, UUIDs, timestamps, tombstones, JSON export, CSV export, transactional record merge |
| Future boundaries | Sync interface; no cloud transport, no AI requirement |

## Night Lock setup

Night Lock starts **disabled** until you deliberately enable it. On Android:

1. Open **Settings → Night Lock → Essential apps** and choose your clock/alarm, authenticator, and any other essential apps by package identity.
2. Read the in-app disclosure, then enable the **Restriction service** in Android Accessibility settings.
3. Optionally grant **Exact alarms** and **Notifications** for more timely schedule boundaries and warnings. Grant **Usage Access** separately if you want phone analytics.
4. Set start/end, then enable the schedule. For initial tests, choose a start a few minutes ahead while you are awake and have another means of communication.
5. Complete the [device checks](docs/DEVICE_TESTS.md) before relying on the feature overnight.

The restriction screen has immediate emergency access. Ordinary temporary access requires a 10-second hold, a reason and confirmation. Native history retains the latest 200 overrides. Emergency escape has a process-local fallback if writing the native preferences fails.

This app cannot power off or boot a phone, make itself uninstall-proof, block all system surfaces, or guarantee operation after force-stop. Revoking the service disables enforcement. System settings, the phone UI, keyguard and system safety surfaces remain available. Some manufacturers may stop/restrict the service. Native schedule state is reconstructed, but displaying an overlay depends on the OS connecting the service and an observable foreground-app event.

Android documentation describes [exact alarm access checks and revocation](https://developer.android.com/develop/background-work/services/alarms). Use of the accessibility API requires explicit disclosure and applicable policy review; this app declares itself **not** a disability accessibility tool, following [Google Play's policy distinction](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en). A successful personal sideload is not evidence of store approval.

## What is still missing

The complete supplied product vision spans twelve development phases. This release does not claim to finish them. Major remaining work:

- Compile/analyze Flutter and Kotlin, fix any SDK compatibility issues, inspect real UI, and run real-device and Windows acceptance tests.
- Daytime app/category budgets with enforcement, limit warnings, cooldowns and focus-based blocking.
- Break cycles, background focus completion notifications, reliable interruption observation, richer recurrence and project milestones.
- Continuous Night Lock observation, compliance sessions and verified overnight streaks. Schedule-enabled time is **not** treated as successful enforcement.
- Fully validated long-term usage analytics, categories, launch/session counts, heatmaps, period comparisons and statistical insights.
- Full backup restoration including usage and settings; current import intentionally merges records only. Database encryption, complete deletion controls and retention policies.
- Cross-device pairing, authenticated encrypted sync and real Windows phone status.
- Automatic metric-linked goals, richer reporting and optional AI.

See [phase status](docs/STATUS.md), [architecture](docs/ARCHITECTURE.md), [validation evidence](docs/VALIDATION.md), and [Android constraints](docs/ANDROID.md).

## Verification commands

```powershell
python tools/check_native.py
python tools/check_source.py
flutter analyze --no-fatal-infos
flutter test
```

The first command compiles the **same Java classes used by Android**, then runs boundary, DST, timezone, override and usage-aggregation tests. The second executes the **actual shipped SQL schema** in SQLite and checks Android XML/permission declarations. Neither substitutes for Flutter compilation or Android lifecycle tests.
