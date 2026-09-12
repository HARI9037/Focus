# Focus architecture

## Platform ownership

Flutter owns the productivity workspace: presentation, user intents and SQLite records. The native Android runtime owns restriction state, warnings, emergency escape, package allowlists and override expiry. No Flutter timer controls overnight enforcement.

| Layer | Files | Responsibility |
| --- | --- | --- |
| Presentation | `lib/app/focus_app.dart`, `screens.dart`, `editor.dart`, `settings_screen.dart` | Adaptive shell, accessible controls, forms, charts and disclosures |
| Application | `lib/app/controller.dart` | User intents, error boundaries, reloads, local timer presentation, platform refresh |
| Domain | `features/tasks/domain`, `features/analytics/domain`, `features/night_lock/domain` | Recurrence, task-derived progress, aggregation, explained scores, schedule preview |
| Persistence | `core/database` | SQLite versioning, record repository, usage-day upserts, transactional merge/export |
| Platform | `core/platform/device_bridge.dart` | Explicit Android capability API; unsupported response on Windows |
| Native runtime | `native/android/...` | Kotlin integration and Java scheduling/usage policies |
| Local sync | `core/sync` | Explicit AES-GCM authenticated snapshot exchange with temporary pairing |

Widgets invoke controller/repository operations rather than embedding SQL or querying Android APIs. The initial controller currently uses the concrete local repository for settings/export; more complete repository interfaces should be introduced as those domains stabilize. Pure domain calculations do not depend on Flutter widgets.

## Local database v2

`records` stores a UUID, feature kind, title/body, state, priority, project reference, due UTC timestamp, created/updated UTC timestamps, tombstone and a feature-owned JSON payload. Indexed columns cover kind/state, due time, project and update cursors. Feature payloads cover tags, recurrence, session timing, goal progress and habit civil dates.

`preferences` stores local configuration as JSON values. `usage_daily` stores day/package/app label/duration/collection timestamp/quality with a composite primary key. A reimport atomically replaces the observed day to prevent duplicate time.

SQLite enables foreign-key enforcement and WAL. V1 has no actual foreign-key references because project deletion preserves linked records for recovery; dangling references display as unassigned in editors. Future relational migrations must define unlink/tombstone policies deliberately. No new schema version may ship without a tested forward migration; unsupported downgrades refuse to reset user data.

Task completion rereads the current task inside a transaction, marks it complete and inserts the next occurrence exactly once. Monthly recurrence clamps to the following month's final day. It advances from the most recent due date; end-of-month anchor preservation is future work. A large overdue backlog is not silently marked complete.

JSON exports include records (including tombstones), preferences, usage, note versions and the available native Night Lock snapshot. CSV neutralizes leading spreadsheet formula characters. JSON restore merges records, usage and note versions transactionally and restores theme/daily targets. It does not grant permissions or restore restriction configuration. The v1-to-v2 migration adds record_versions; overwritten notes and ideas retain up to twenty revisions.

## Session accounting

An active session is a persisted record with UTC start and optional target end. UI timers derive remaining time from timestamps. On restart, an expired fixed-duration session is completed at its planned endpoint, not the later restart time. Open-ended time continues until explicitly ended; unattended gaps are a known limitation and must not be interpreted as observed attention.

Completed/interrupted intervals are clipped to each report window. A session crossing midnight contributes only overlapping seconds to each day. Active records and explicit break sessions are excluded from focus totals. Android completion/reminder alarms are persisted natively and rescheduled after boot; Windows currently shows completion only while the application is open.

## Native Night Lock

`NightPolicy` uses real intervals constructed from local dates and a `ZoneId`. The start is inclusive; the end is exclusive. Overnight and same-day schedules are supported. Equal boundaries are invalid. Java resolves nonexistent DST start times forward and ambiguous times to the earlier offset; tests cover common spring/fall nights and the repeated-hour end case.

`NightStore` persists policy and the latest 200 overrides in private SharedPreferences. The native values are authoritative; SQLite mirrors configuration for future UI/sync work. Native commits are attempted before Flutter marks configuration saved. Monotonic `elapsedRealtime` and the OS boot counter control override expiry. Wall-clock changes do not lengthen a temporary override. Reboot terminates it. Changing the schedule terminates it. An expired record is finalized when the runtime next evaluates state.

`NightScheduler` schedules one next boundary using AlarmManager. It checks exact-alarm access and falls back to an inexact alarm. Pre-lock warning boundaries are 20, 10 and 5 minutes. Doze may defer closely spaced alarms; a connected service also maintains its next boundary callback. The callback is an optimization, not the durable scheduler.

`FocusAccessibilityService` receives window-state events after explicit disclosure. It does not retrieve window content or perform gestures. For a nonessential foreground app during Night Lock, it displays a scrollable accessibility overlay. It avoids the keyguard, screen-off state, system UI, phone surfaces and settings. While visible, a one-second callback refreshes the countdown; it does not poll UsageStats. Reboot/time/upgrade broadcasts reschedule and reconcile available native state.

The overlay ordinary override flow is hold → reason → confirm. Emergency escape bypasses the hold, records the event where storage is working, removes the overlay and opens the dialer. A temporary in-memory escape is retained if persistence fails. No phone-call permission is required, and the app never places a call automatically.

## Usage and analytics quality

Usage imports run on opening/resuming Android when permission is available, or by user request, with a one-day lookback to reconstruct foreground state across midnight. The accumulator clips intervals, ignores duplicate resume events and unrelated pauses, closes on screen-off/keyguard/shutdown, and aggregates by package. Missing/truncated events, OEM differences, multi-window and long-running sessions affect accuracy. No-data days remain unknown. Daytime budget enforcement reads usage on foreground changes and schedules the next warning/budget boundary.

Productivity scores use planned-task completion (50%) and focus target attainment (50%). Discipline scores use observed phone budget adherence (60%) and fully observed Night Lock compliance (40%). Values are clipped to 0–1, available weights renormalized, and coverage displayed. Observation gaps remain unknown. Reports use recorded outcomes and guarded comparisons; correlation requires fourteen paired observations with variation and never claims causation.

## Local sync and future AI

Manual pairing exchanges a random 256-bit key through a temporary code; TCP messages are encrypted/authenticated with AES-GCM and directional associated data. Pairing expires after ten minutes. Size/connection limits, timeouts and request replay guards bound the listener. Sync merges timestamped records with a deterministic tie-break and retains previous note versions. Active sessions and restriction settings do not sync. Android usage and native state become dated Windows snapshots. Automatic incremental sync and device-clock reconciliation remain future work.

An eventual AI adapter should receive sanitized aggregate summaries and propose mutations for confirmation. No AI provider or telemetry SDK is present. Network use is limited to user-initiated encrypted LAN pairing and sync.
