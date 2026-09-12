import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

/// Call sites provide static event codes only; no exceptions, notes, app IDs or payloads.
void logEvent(LogLevel level, String code) {
  if (!RegExp(r'^[a-z_]{1,64}$').hasMatch(code)) return;
  developer.log(code, name: 'focus.${level.name}');
}
