# Android implementation and constraints

Minimum configured Android SDK: 26 (Android 8). Target/compile SDK are inherited from the selected Flutter SDK and must be reviewed before any public release. The native code uses Java 17 build tooling; `java.time` is available from Android API 26.

| Capability | Mechanism | Limit |
| --- | --- | --- |
| App foreground estimates | UsageStatsManager.queryEvents after Usage Access | OS event retention and lifecycle gaps; not exact physical screen time |
| Restriction overlay | Opt-in AccessibilityService, TYPE_ACCESSIBILITY_OVERLAY | Service can be disabled or stopped; system/safety surfaces remain accessible |
| Schedule wakeup | AlarmManager exact alarm with access check; inexact fallback | Doze/OEM policies can delay execution and warnings |
| Foreground reconciliation | Window-state events | No overlay can be safely targeted until foreground app identity is known |
| Recovery | Boot, time/timezone, package update and exact-permission broadcasts | Force-stopped apps do not recover until explicitly reopened; boot recovery waits for user unlock/OS service connection |
| Notifications | NotificationManager and runtime notification permission | Denial/channel settings can suppress warnings |
| App selection | Launcher-intent package visibility query | Does not enumerate every hidden/system package; no broad package query permission |
| Emergency communication | Immediate override and ACTION_DIAL | No automatic call, no CALL_PHONE permission; safety settings fallback |
| Exports | ACTION_CREATE_DOCUMENT through native channel | User chooses destination; cancellation/error returned to UI |

Only Usage Access, optional notification/exact alarm access and the explicitly enabled accessibility service are used. No Notification Listener, Device Owner, overlay special permission, foreground service, battery exemption, contacts permission, Internet permission or root operation is requested by the main application manifest. Flutter-generated debug runners add Internet permission for development VM-service tooling; no telemetry implementation is included.

The accessibility service declares `isAccessibilityTool=false`, `canRetrieveWindowContent=false` and `canPerformGestures=false`. The in-app disclosure explains what is observed, why, how it is processed locally and how to revoke access. It does not inspect UI text, passwords or screenshots. Personal-use distribution and store distribution still need the appropriate platform/policy review.

The app does **not** hide uninstall controls, automate settings, silently re-enable permissions, or claim tamper resistance. On devices that present restricted-settings gates, follow the operating system's official user flow; no bypass is implemented.

Alarm/clock and authenticator apps should be explicitly selected by package identity. Category names do not automatically whitelist packages. The phone package and essential system surfaces have separate safety handling. OEM dialers, emergency screens and incoming-call interactions require testing on the actual target device.

Cloud backup and automatic device transfer exclusions are declared to keep behavioral information local. Manual exports are cleartext and controlled by the user. App-private files and OS device encryption are the current security boundary; this is not database-level encryption.

## Primary references checked while authoring

- [Schedule alarms and check exact-alarm access](https://developer.android.com/develop/background-work/services/alarms)
- [Exact alarms denied by default on affected Android 14 installs](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms)
- [AccessibilityService API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)
- [Accessibility API disclosure and non-accessibility-tool policy](https://support.google.com/googleplay/android-developer/answer/10964491?hl=en)
- [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)

Store readiness, Android API compilation and OEM behavior are not established by reading documentation.
