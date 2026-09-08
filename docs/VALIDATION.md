# Validation evidence

Recorded during source creation on 2026-09-08.

| Check | Actual result |
| --- | --- |
| Java scheduling/usage source compilation | Passed using installed Java 17 compiler module |
| Native policy test program | Passed: 51,875 assertions, mostly exhaustive minute-of-day membership/next-boundary invariants plus targeted cases |
| Targeted native cases | Overnight/same-day boundaries, warning boundaries, timezone, spring/fall DST, repeated-hour end, override expiry, invalid schedules, foreground switching, duplicate resume, stale pause, screen-off, range clipping |
| Actual SQLite schema execution | Passed: 8 schema/index statements, integrity check, negative-usage and duplicate-day constraints |
| Android XML | Four files parsed successfully; declarations checked for minimal selected permissions |
| Flutter/Dart tests | Authored, **not run**; no Flutter/Dart SDK available |
| Flutter static analysis | **Not run**; compiler/analyzer unavailable |
| Kotlin/Android compilation | **Not run**; Android SDK/Kotlin toolchain unavailable |
| APK | **Not built** |
| Windows executable | **Not built** |
| UI screenshots/visual inspection | **Not performed**; no rendered-app image is presented |
| Android lifecycle/OEM/battery tests | **Not performed** |
| GitHub Actions | Workflow authored, **not triggered** |

The large assertion count is primarily a finite sweep of schedule minutes, not tens of thousands of independent real-device scenarios. These results validate only the pure policies and the shipped schema/declarations. They do not establish successful app compilation or production reliability.

Reproduce available checks with `python tools/check_native.py` and `python tools/check_source.py`. On a configured Flutter machine, bootstrap runners, then run the analyzer/tests/builds before manual device acceptance.
