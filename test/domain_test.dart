import 'package:flutter_test/flutter_test.dart';
import 'package:focus/features/tasks/domain/entry.dart';
import 'package:focus/features/night_lock/domain/night_schedule.dart';
import 'package:focus/features/analytics/domain/analytics.dart';

void main() {
  group('Civil recurrence', () {
    test('monthly clamps Jan 31 to leap-day February', () {
      expect(
        nextOccurrence(DateTime(2024, 1, 31, 10), 'monthly'),
        DateTime(2024, 2, 29, 10),
      );
    });
    test('weekly crosses year boundary', () {
      expect(
        nextOccurrence(DateTime(2025, 12, 28, 9), 'weekly'),
        DateTime(2026, 1, 4, 9),
      );
    });
    test('none never creates another task', () {
      expect(nextOccurrence(DateTime.now(), 'none'), isNull);
    });
  });
  group('Schedule preview', () {
    final policy = NightSchedule(enabled: true);
    test('inclusive night start, exclusive morning end', () {
      expect(
        policy.state(DateTime(2026, 9, 8, 21)),
        NightState.nightLockActive,
      );
      expect(
        policy.state(DateTime(2026, 9, 9, 6, 59)),
        NightState.nightLockActive,
      );
      expect(policy.state(DateTime(2026, 9, 9, 7)), NightState.dayActive);
    });
    test('20 minute warning', () {
      expect(
        policy.state(DateTime(2026, 9, 8, 20, 40)),
        NightState.preLockWarning,
      );
    });
    test('expired override returns to restriction', () {
      final now = DateTime(2026, 9, 8, 23);
      expect(policy.state(now, overrideUntil: now), NightState.nightLockActive);
    });
    test('invalid identical boundaries rejected', () {
      expect(
        () => NightSchedule(startMinute: 420, endMinute: 420),
        throwsArgumentError,
      );
    });
  });
  test('project progress excludes cancelled and deleted tasks', () {
    final entries = [
      Entry(kind: 'task', title: 'A', projectId: 'p', state: 'completed'),
      Entry(kind: 'task', title: 'B', projectId: 'p', state: 'planned'),
      Entry(kind: 'task', title: 'C', projectId: 'p', state: 'cancelled'),
    ];
    expect(projectProgress(entries, 'p'), .5);
  });
  test('missing measurements are not a perfect score or zero', () {
    final score = AnalyticsEngine.discipline(budgetSeconds: 3600);
    expect(score.value, isNull);
    expect(score.coverage, 0);
  });
  test('score exposes weighting and clips excessive focus', () {
    final score = AnalyticsEngine.productivity(
      completed: 1,
      planned: 2,
      focusSeconds: 7200,
      targetSeconds: 3600,
    );
    expect(score.value, 75);
    expect(score.coverage, 1);
  });
  test('streak does not reset before today is over', () {
    expect(
      AnalyticsEngine.streak({
        '2026-09-06',
        '2026-09-07',
      }, DateTime(2026, 9, 8, 8)),
      2,
    );
    expect(AnalyticsEngine.streak({'2026-09-06'}, DateTime(2026, 9, 8)), 0);
  });
  test('longest streak crosses months', () {
    expect(
      AnalyticsEngine.longestStreak({
        '2026-08-31',
        '2026-09-01',
        '2026-09-02',
        '2026-09-04',
      }),
      3,
    );
  });
  test('focus allocation splits midnight', () {
    final start = DateTime(2026, 9, 8, 23, 50),
        end = DateTime(2026, 9, 9, 0, 20);
    final session = Entry(
      kind: 'session',
      title: 'Study',
      state: 'completed',
      data: {
        'startedAt': start.toIso8601String(),
        'endedAt': end.toIso8601String(),
      },
    );
    expect(
      AnalyticsEngine.focusSeconds(
        [session],
        DateTime(2026, 9, 8),
        DateTime(2026, 9, 9),
      ),
      600,
    );
    expect(
      AnalyticsEngine.focusSeconds(
        [session],
        DateTime(2026, 9, 9),
        DateTime(2026, 9, 10),
      ),
      1200,
    );
  });
  test('trend needs a nonzero baseline', () {
    expect(AnalyticsEngine.usageChange(10, 0), isNull);
    expect(AnalyticsEngine.usageChange(83, 100), contains('17% lower'));
  });
}
