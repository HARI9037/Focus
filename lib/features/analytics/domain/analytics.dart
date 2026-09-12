import '../../tasks/domain/entry.dart';

class ScorePart {
  final String name;
  final double? value;
  final double weight;
  const ScorePart(this.name, this.value, this.weight);
}

class ExplainedScore {
  final List<ScorePart> parts;
  const ExplainedScore(this.parts);
  double? get value {
    final available = parts.where((p) => p.value != null && p.weight > 0);
    final total = available.fold<double>(0, (s, p) => s + p.weight);
    if (total == 0) return null;
    return available.fold<double>(
          0,
          (s, p) => s + p.value!.clamp(0, 1) * p.weight,
        ) /
        total *
        100;
  }

  double get coverage {
    final total = parts.fold<double>(0, (s, p) => s + p.weight);
    if (total == 0) return 0;
    return parts
            .where((p) => p.value != null)
            .fold<double>(0, (s, p) => s + p.weight) /
        total;
  }
}

class AnalyticsEngine {
  static int focusSeconds(
    Iterable<Entry> entries,
    DateTime start,
    DateTime end,
  ) {
    // Session seconds are sliced at local period boundaries, never assigned wholly to start day.
    var result = 0;
    for (final e in entries.where(
      (e) =>
          e.kind == 'session' &&
          !e.deleted &&
          e.state != 'active' &&
          e.data['isBreak'] != true,
    )) {
      final a = DateTime.tryParse(e.data['startedAt'] as String? ?? '');
      final b = DateTime.tryParse(e.data['endedAt'] as String? ?? '');
      if (a == null || b == null || !b.isAfter(a)) continue;
      final left = a.isAfter(start) ? a : start;
      final right = b.isBefore(end) ? b : end;
      if (right.isAfter(left)) result += right.difference(left).inSeconds;
    }
    return result;
  }

  static ExplainedScore productivity({
    required int completed,
    required int planned,
    required int focusSeconds,
    required int targetSeconds,
  }) => ExplainedScore([
    ScorePart(
      'Planned tasks completed',
      planned > 0 ? completed / planned : null,
      0.5,
    ),
    ScorePart(
      'Focus target reached',
      targetSeconds > 0 ? focusSeconds / targetSeconds : null,
      0.5,
    ),
  ]);
  static ExplainedScore discipline({
    int? usageSeconds,
    required int budgetSeconds,
    double? nightCompliance,
  }) => ExplainedScore([
    ScorePart(
      'Phone budget',
      usageSeconds == null || budgetSeconds <= 0
          ? null
          : (usageSeconds <= budgetSeconds ? 1 : budgetSeconds / usageSeconds),
      0.6,
    ),
    ScorePart('Observed Night Lock compliance', nightCompliance, 0.4),
  ]);
  static String? usageChange(double current, double previous) {
    if (previous <= 0) return null;
    final percent = ((current - previous) / previous * 100).round();
    if (percent == 0) {
      return 'Phone usage was unchanged across these observed periods.';
    }
    return 'Phone usage was ${percent.abs()}% ${percent < 0 ? 'lower' : 'higher'} than the previous observed period.';
  }

  static int streak(Set<String> completedDays, DateTime now) {
    var cursor = DateTime(now.year, now.month, now.day);
    if (!completedDays.contains(dayKey(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    var count = 0;
    while (completedDays.contains(dayKey(cursor))) {
      count++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return count;
  }

  static int longestStreak(Set<String> days) {
    var longest = 0;
    for (final d in days) {
      final n = streak(days, DateTime.parse(d));
      if (n > longest) longest = n;
    }
    return longest;
  }
}
