# Scope and phase status

Status describes source implementation, not runtime acceptance. No phase is signed off for production until Flutter, Android and Windows verification gates pass.

| Phase from brief | Present | Still required |
| --- | --- | --- |
| 0 Foundation | Flutter application, runner bootstrap, themes, SQLite v1, repository, privacy-safe log codes, settings and tests | First compiler run, dependency lock, migration fixtures for future versions, full secure-storage integration |
| 1 Productivity core | Today, Inbox, tasks, basic projects, notes, capture, agenda | Milestones, actual task-duration rollups in task UI, task-note links, background reminders, advanced recurrence |
| 2 Focus engine | Persisted session lifecycle, presets, custom/open-ended timer, history, task association | Pomodoro breaks, blocking integration, OS completion notifications, observed interruptions |
| 3 Night Lock | Native deterministic policy, alarms, warning categories, event-driven overlay, package whitelist, overrides, recovery and optional permission disclosure | Physical-device testing, OEM battery behavior, accessible alternative to timed hold, continuous observation/audit, schedule application confirmation UX |
| 4 Device usage | On-demand event aggregation and daily app totals | Categories, launch counts, longest sessions, historical quality markers, enforced budgets and cooldowns |
| 5 Analytics | Focus aggregation, daily app totals, 1/7/30-day selection, basic bars, explained scores | Persisted computed summaries, rich reports, comparisons, heatmaps, complete coverage accounting |
| 6 Insights | Pure noncausal usage-change rule with tests | UI pipeline, comparable-period guards, correlations, sample-size thresholds, persisted insight generation |
| 7 Goals and habits | Manual goals, check-ins, streaks | Metric links and automatic progress, completion-rate denominators |
| 8 Windows | Responsive sidebar, search and Ctrl+N capture; official runner generation | Windows executable verification, phone dashboard after sync, system shortcuts, installer |
| 9 Sync | Provider interface and record envelopes only | Pairing/authentication, transport, conflicts, encryption, per-device clocks/cursors, real end-to-end sync |
| 10 Hardening | Initial checks and explicit device acceptance plan | Security, permission, accessibility, battery, lifecycle, migration and performance gates |
| 11 Intelligence | Core works without AI; architecture permits a later adapter | Sanitized context contract, providers, proposals/approval and tool execution |

## Recommended next sequence

1. Get a clean Flutter analysis/test run and debug APK on the target phone. Validate every existing CRUD and session workflow before adding features.
2. Verify immediate emergency access, end-of-night removal, permission revocation, reboot, time changes and force-stop recovery. Fix these before adding daytime blocking.
3. Add native observation sessions with explicit unknown intervals. Derive Night Lock compliance only from observed evidence.
4. Stabilize the usage importer, then add explicit package categories and a single per-app daily budget end to end.
5. Implement reports and period coverage, then secure sync after local behavior is stable.

## Product decisions

- Safety settings are reachable. This is intentional voluntary discipline, not device-owner kiosk mode.
- Goals are explicitly manual in this version. No inferred progress is fabricated.
- “Screen time” is labelled as app foreground estimates, not a precise physical-display metric.
- Focus time measures session elapsed time. Closing the UI does not prove continued attention.
- No sample usage, tasks, streaks or phone connection is populated by default.
- Source architecture groups lightweight feature data in a common record envelope. It is not a finished strongly typed repository for every future entity.
