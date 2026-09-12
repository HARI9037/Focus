# Validation evidence

Updated 2026-09-09 on the user's Windows workspace.

| Check | Observed result |
| --- | --- |
| Flutter static analysis | Passed, no issues |
| Flutter unit, database, socket and widget tests | 42 passed |
| Phone-sized capture | All eight record types pass at 360 logical pixels; milestone list/project/search regression passes |
| Native Java policy/usage | 51,875 assertions passed |
| Native discipline policy | Budget/group/warning/focus/cooldown/permission/boundary checks passed |
| SQLite schema and Android declarations | 9 SQL statements, integrity/constraints and 4 XML files passed |
| Windows runtime | Compiled and launched; task capture and SQLite close/reopen persistence passed |
| Android API 36.1 emulator runtime | Compiled, installed and launched; native status/app enumeration, task capture and SQLite reopen passed using Flutter driver |
| Release packaging | Final signed Android and Windows builds in progress; see build output before treating a package as final |
| Physical Android phone | Not connected in ADB; device acceptance pending |
| Overnight restrictions/OEM lifecycle | Not yet accepted on physical hardware |
| Physical Android-to-Windows sync | Not yet accepted; authenticated local socket tests pass |
| GitHub Actions | Local workflow corrected; no successful remote run of these changes claimed |

Evidence logs in the local workspace: analysis-results.log, test-results.log, runtime-windows.log, runtime-android-drive.log. Build logs are separate. Logs are ignored by Git. The Android test harness initially failed because the emulator was stopped or booting; a subsequent run with the correct Flutter driver harness passed.

The large Java assertion count is primarily a finite sweep of schedule minutes, not thousands of real-device scenarios. Neither emulator success nor compilation establishes reliable overnight enforcement on a particular phone. Complete DEVICE_TESTS.md on the target phone before relying on Night Lock.

Toolchain used: Flutter 3.41.4 / Dart 3.11.1, Java 17, Android SDK 36, Visual Studio 2022 Build Tools with C++ workload. Application behavior remains local-first. The encrypted sync tests cover authenticated transport and rejection behavior, not physical network/firewall acceptance.
