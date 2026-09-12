import 'dart:math' as math;
import '../../tasks/domain/entry.dart';
import 'analytics.dart';

class PeriodReport {
  final DateTime start, end;
  final int tasksCreated,
      tasksCompleted,
      overdue,
      focusSeconds,
      sessions,
      habitCheckins;
  final Map<String, int> apps, categories;
  final List<String> insights;
  final int observedDays, usageSeconds, overrides;
  const PeriodReport({
    required this.start,
    required this.end,
    required this.tasksCreated,
    required this.tasksCompleted,
    required this.overdue,
    required this.focusSeconds,
    required this.sessions,
    required this.habitCheckins,
    required this.apps,
    required this.categories,
    required this.insights,
    required this.observedDays,
    required this.usageSeconds,
    required this.overrides,
  });
  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'endExclusive': end.toIso8601String(),
    'tasksCreated': tasksCreated,
    'tasksCompleted': tasksCompleted,
    'overdue': overdue,
    'focusSeconds': focusSeconds,
    'sessions': sessions,
    'habitCheckins': habitCheckins,
    'observedUsageDays': observedDays,
    'usageSeconds': usageSeconds,
    'appSeconds': apps,
    'categorySeconds': categories,
    'recordedOverrides': overrides,
    'insights': insights,
  };
}

class ReportEngine {
  static PeriodReport create(
    List<Entry> entries,
    List<Map<String, Object?>> usage,
    List<Map<String, dynamic>> rules,
    List<dynamic> overrides,
    DateTime start,
    DateTime end,
  ) {
    bool within(DateTime? d) =>
        d != null && !d.isBefore(start) && d.isBefore(end);
    final tasks = entries.where((e) => e.kind == 'task' && !e.deleted).toList();
    final rows = usage
        .where(
          (r) =>
              (r['day'] as String).compareTo(dayKey(start)) >= 0 &&
              (r['day'] as String).compareTo(dayKey(end)) < 0,
        )
        .toList();
    final apps = <String, int>{}, categories = <String, int>{};
    for (final r in rows) {
      final pkg = r['package'] as String;
      apps[pkg] = (apps[pkg] ?? 0) + (r['milliseconds'] as int) ~/ 1000;
    }
    for (final rule in rules) {
      categories[rule['label'] as String] = (rule['packages'] as List)
          .fold<int>(0, (sum, p) => sum + (apps[p] ?? 0));
    }
    final focus = AnalyticsEngine.focusSeconds(entries, start, end);
    final previousStart = DateTime(
      start.year,
      start.month,
      start.day - end.difference(start).inDays,
    );
    final previousFocus = AnalyticsEngine.focusSeconds(
      entries,
      previousStart,
      start,
    );
    final insights = <String>[];
    if (previousFocus > 0) {
      insights.add(
        'Recorded focus: ${(focus / 3600).toStringAsFixed(1)}h in this period versus ${(previousFocus / 3600).toStringAsFixed(1)}h in the preceding period. Today may still be in progress.',
      );
    }
    final currentDays = rows.map((r) => r['day']).toSet();
    final previousRows = usage
        .where(
          (r) =>
              (r['day'] as String).compareTo(dayKey(previousStart)) >= 0 &&
              (r['day'] as String).compareTo(dayKey(start)) < 0,
        )
        .toList();
    final expected = end.difference(start).inDays;
    if (currentDays.length == expected &&
        previousRows.map((r) => r['day']).toSet().length == expected &&
        end.isBefore(DateTime.now())) {
      final previous = previousRows.fold<int>(
        0,
        (s, r) => s + (r['milliseconds'] as int),
      );
      final change = AnalyticsEngine.usageChange(
        rows.fold<int>(0, (s, r) => s + (r['milliseconds'] as int)).toDouble(),
        previous.toDouble(),
      );
      if (change != null) insights.add(change);
    }
    final pairs = <List<double>>[];
    for (final key in currentDays) {
      final day = DateTime.parse(key as String);
      if (dayKey(day) == dayKey(DateTime.now())) continue;
      final next = DateTime(day.year, day.month, day.day + 1);
      pairs.add([
        rows
                .where((r) => r['day'] == key)
                .fold<int>(0, (s, r) => s + (r['milliseconds'] as int)) /
            3600000,
        AnalyticsEngine.focusSeconds(entries, day, next) / 3600,
      ]);
    }
    final r = correlation(pairs);
    if (r != null && r.abs() >= .4) {
      insights.add(
        'Across ${pairs.length} recorded days, higher phone use occurred alongside ${r < 0 ? 'less' : 'more'} focus time (r=${r.toStringAsFixed(2)}). This association does not establish a cause.',
      );
    }
    if (focus == 0) {
      insights.add(
        'Start with one short focus session and a single planned task.',
      );
    }
    if (currentDays.isEmpty) {
      insights.add(
        'Import phone usage to include device behavior. Missing days are not zero-use days.',
      );
    }
    return PeriodReport(
      start: start,
      end: end,
      tasksCreated: tasks.where((e) => within(e.createdAt)).length,
      tasksCompleted: tasks
          .where(
            (e) =>
                e.state == 'completed' &&
                within(
                  DateTime.tryParse(e.data['completedAt'] as String? ?? ''),
                ),
          )
          .length,
      overdue: tasks
          .where(
            (e) =>
                !['completed', 'cancelled'].contains(e.state) &&
                e.dueAt != null &&
                e.dueAt!.isBefore(DateTime.now()),
          )
          .length,
      focusSeconds: focus,
      sessions: entries
          .where(
            (e) =>
                e.kind == 'session' &&
                e.state != 'active' &&
                e.data['isBreak'] != true &&
                within(DateTime.tryParse(e.data['startedAt'] as String? ?? '')),
          )
          .length,
      habitCheckins: entries
          .where((e) => e.kind == 'habit')
          .fold<int>(
            0,
            (s, e) =>
                s +
                (e.data['days'] as List? ?? [])
                    .where((d) => within(DateTime.tryParse(d as String)))
                    .length,
          ),
      apps: apps,
      categories: categories,
      insights: insights,
      observedDays: currentDays.length,
      usageSeconds: apps.values.fold<int>(0, (s, v) => s + v),
      overrides: overrides
          .where(
            (o) =>
                o is Map &&
                o['startedAt'] is num &&
                within(
                  DateTime.fromMillisecondsSinceEpoch(
                    (o['startedAt'] as num).toInt(),
                  ),
                ),
          )
          .length,
    );
  }

  static double? correlation(List<List<double>> pairs) {
    if (pairs.length < 14) return null;
    final mx = pairs.fold<double>(0, (s, p) => s + p[0]) / pairs.length,
        my = pairs.fold<double>(0, (s, p) => s + p[1]) / pairs.length;
    double xy = 0, xx = 0, yy = 0;
    for (final p in pairs) {
      final x = p[0] - mx, y = p[1] - my;
      xy += x * y;
      xx += x * x;
      yy += y * y;
    }
    if (xx <= 0 || yy <= 0) return null;
    return xy / math.sqrt(xx * yy);
  }

  static double goalProgress(Entry goal, List<Entry> entries, DateTime now) {
    final start =
        DateTime.tryParse(goal.data['startAt'] as String? ?? '') ??
        goal.createdAt;
    final end = goal.dueAt != null && goal.dueAt!.isBefore(now)
        ? goal.dueAt!
        : now;
    switch (goal.data['metric']) {
      case 'focusHours':
        return AnalyticsEngine.focusSeconds(
              entries.where(
                (e) => goal.projectId == null || e.projectId == goal.projectId,
              ),
              start,
              end,
            ) /
            3600;
      case 'tasksCompleted':
        return entries
            .where(
              (e) =>
                  e.kind == 'task' &&
                  e.state == 'completed' &&
                  (goal.projectId == null || e.projectId == goal.projectId) &&
                  DateTime.tryParse(e.data['completedAt'] as String? ?? '') !=
                      null,
            )
            .where((e) {
              final d = DateTime.parse(e.data['completedAt'] as String);
              return !d.isBefore(start) && !d.isAfter(end);
            })
            .length
            .toDouble();
      case 'projectPercent':
        return goal.projectId == null
            ? 0
            : projectProgress(entries, goal.projectId!) * 100;
      default:
        return (goal.data['current'] as num? ?? 0).toDouble();
    }
  }
}
