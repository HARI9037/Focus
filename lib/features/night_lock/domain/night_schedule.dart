enum NightState { disabled, dayActive, preLockWarning, nightLockActive, temporaryOverride }

/// Desktop schedule preview only. Android's persisted native state is authoritative
/// for enforcement and override expiry; Windows never claims to know phone state.
class NightSchedule {
  final int startMinute, endMinute;
  final bool enabled;
  NightSchedule({this.startMinute = 1260, this.endMinute = 420, this.enabled = false}) {
    if (startMinute < 0 || startMinute >= 1440 || endMinute < 0 || endMinute >= 1440 || startMinute == endMinute) {
      throw ArgumentError('Schedule needs distinct times within a day');
    }
  }
  bool contains(DateTime now) {
    final m = now.hour * 60 + now.minute;
    return startMinute > endMinute ? m >= startMinute || m < endMinute : m >= startMinute && m < endMinute;
  }
  DateTime nextEnd(DateTime now) {
    var end = DateTime(now.year,now.month,now.day,endMinute~/60,endMinute%60);
    if (!end.isAfter(now)) end = DateTime(now.year,now.month,now.day+1,endMinute~/60,endMinute%60);
    return end;
  }
  NightState state(DateTime now, {DateTime? overrideUntil}) {
    if (!enabled) return NightState.disabled;
    if (contains(now)) {
      return overrideUntil != null && overrideUntil.isAfter(now) ? NightState.temporaryOverride : NightState.nightLockActive;
    }
    final start = DateTime(now.year,now.month,now.day,startMinute~/60,startMinute%60);
    final delta = start.difference(now).inSeconds;
    return delta > 0 && delta <= 1200 ? NightState.preLockWarning : NightState.dayActive;
  }
}
