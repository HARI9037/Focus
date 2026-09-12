import '../../analytics/domain/analytics.dart';
import '../../tasks/domain/entry.dart';

class NightSummary {
  final int recorded, fullyObserved, successful;
  final double observedHours;
  final Set<String> successfulDays;
  NightSummary(List<dynamic> nights, List<dynamic> overrides, DateTime now)
    : recorded = nights.length,
      fullyObserved = nights.where((n) => _observed(n, now)).length,
      successful = nights
          .where((n) => _observed(n, now) && !_overridden(n, overrides))
          .length,
      observedHours = nights.fold<double>(
        0,
        (s, n) => s + (n['observedMs'] as num? ?? 0) / 3600000,
      ),
      successfulDays = nights
          .where((n) => _observed(n, now) && !_overridden(n, overrides))
          .map(
            (n) => dayKey(
              DateTime.fromMillisecondsSinceEpoch((n['end'] as num).toInt()),
            ),
          )
          .toSet();
  static bool _observed(dynamic n, DateTime now) =>
      n is Map &&
      n['end'] is num &&
      n['start'] is num &&
      (n['end'] as num) <= now.millisecondsSinceEpoch &&
      (n['observedMs'] as num? ?? 0) >=
          ((n['end'] as num) - (n['start'] as num)) - 5000;
  static bool _overridden(dynamic n, List<dynamic> overrides) => overrides.any(
    (o) =>
        o is Map &&
        o['startedAt'] is num &&
        (o['startedAt'] as num) < (n['end'] as num) &&
        (o['startedAt'] as num) + (o['durationMs'] as num? ?? 0) >
            (n['start'] as num),
  );
  double? get compliance =>
      fullyObserved == 0 ? null : successful / fullyObserved;
  int streak(DateTime now) => AnalyticsEngine.streak(successfulDays, now);
  int get longest => AnalyticsEngine.longestStreak(successfulDays);
}
