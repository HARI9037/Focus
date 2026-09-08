# Acceptance checks before relying on Focus

These are required future device tests, **not completed results**. Start with the schedule a few minutes ahead while awake. Do not depend on an unverified app as your only means of maintaining a boundary or contacting help.

## Productivity and Windows

- Create/edit/delete each item type; restart and verify persistence.
- Complete the same recurring task twice rapidly: one next occurrence only.
- Monthly recurrence on January 31 and February leap day; verify documented clamping.
- Assign tasks to a project, complete/cancel them and verify derived progress.
- Capture with Ctrl+N and search body/tags on Windows.
- Run a fixed session through a process restart; verify completion ends at planned timestamp.
- End a session early; confirm state, duration and date-boundary report allocation.
- Open-ended sessions across long app-closed periods must be labelled elapsed, not verified attention.
- Habit check-in/check-out, yesterday streak grace and month transitions.
- Export Unicode/multiline notes and CSV formula-like titles.
- Merge a record backup; newer records and tombstones win. Usage/settings are intentionally not imported.
- Simulate invalid backup and out-of-space writes; no automatic database reset.
- Windows release distribution runs on a clean machine with its SQLite DLL and all Flutter data files.

## Android Night Lock

| Scenario | Expected behavior |
| --- | --- |
| No permissions | Productivity works; usage/service unavailable; no claim of enforcement |
| Schedule enabled, service off | Status explicitly says service is disconnected |
| Service enabled with disclosure accepted | A distracting foreground app receives overlay during scheduled night |
| Default schedule | Start at 21:00 inclusive, end at 07:00 exclusive local time |
| 20/10/5-minute warnings | Respect notifications and warnings toggle; document actual delayed delivery under idle |
| Whitelisted clock/authenticator | Can launch and operate without overlay |
| Immediate emergency action | No hold or reason needed; overlay removed, phone UI opens |
| Incoming call, emergency dialer, keyguard | Never obstruct communication or OS emergency controls |
| Ordinary override | Short hold cancels; 10 seconds opens reasons; Cancel grants nothing; Confirm grants configured interval |
| Override expiry | At expiry, blocking resumes for a currently open restricted app when service is connected |
| Reboot during override | Temporary access terminates; schedule reconstructed after service reconnects |
| Device reboot during night | Schedule persists; overlay returns on next observable foreground event |
| Morning end with same app open | Overlay removed without opening Flutter |
| Change schedule/timezone | Native scheduler and connected service refresh next boundary |
| Clock moved backward during override | Monotonic expiry does not extend |
| Exact-alarm access denied/revoked | No SecurityException crash; inexact fallback and capability label |
| Notifications denied | Core restriction remains optional; warnings may be absent |
| Service disabled or force-stop | No false enforcement claim; user can reopen and re-enable voluntarily |
| Storage write failure during emergency | Immediate in-memory escape remains available |
| Large text/TalkBack | Overlay scrolls; emergency and settings reachable; timed-hold accessibility requires further design |
| App or Android update | Manifest, package visibility, service permission and native integration still operate |

Test on at least Android API 26, 31, 33, 34/35 and the user's actual OEM/OS version. Measure idle battery impact overnight and verify no unexpected wake locks or persistent polling. Repeat after any scheduling/permission/service changes.

## Usage and analytics

- Compare a known sequence of foreground app sessions to imported totals; accept only documented approximation error.
- Verify screen-off and keyguard time is excluded where events are available.
- Cross midnight with the same app open; check clipping to each day's range.
- Repeat import: totals must not double.
- Revoked Usage Access must show unavailable, not a perfect discipline score.
- Multi-window and truncated history must not be presented as exact display usage.
- Missing days must remain distinct from genuine observed zero-use days; improve coverage metadata before trend reporting.
- Do not enable Night Lock compliance streaks until disconnected intervals can be identified and excluded.
