package com.personal.focus;

import java.time.*;
import java.util.*;

/** Pure policy used by the Android runtime. Schedule is local civil time;
 * override expiry is monotonic and cannot be extended by wall-clock changes. */
public final class NightPolicy {
    public enum State { DISABLED, DAY_ACTIVE, PRE_LOCK_WARNING, NIGHT_LOCK_ACTIVE, TEMPORARY_OVERRIDE }
    public final int startMinute, endMinute;
    public final boolean enabled;
    public NightPolicy(int start, int end, boolean enabled) {
        if (start < 0 || start >= 1440 || end < 0 || end >= 1440 || start == end)
            throw new IllegalArgumentException("Invalid schedule");
        this.startMinute = start; this.endMinute = end; this.enabled = enabled;
    }
    private ZonedDateTime at(LocalDate day, int minute, ZoneId zone) {
        // Java resolves nonexistent spring times forward and ambiguous fall times
        // to the earlier offset. The night is an actual interval, never two
        // independent time-of-day comparisons through a repeated DST hour.
        return day.atTime(minute / 60, minute % 60).atZone(zone);
    }
    public Instant[] intervalContaining(Instant now, ZoneId zone) {
        LocalDate day = now.atZone(zone).toLocalDate();
        for (int delta = -1; delta <= 0; delta++) {
            LocalDate startDay = day.plusDays(delta);
            Instant start = at(startDay, startMinute, zone).toInstant();
            Instant end = at(startDay.plusDays(startMinute > endMinute ? 1 : 0), endMinute, zone).toInstant();
            if (!now.isBefore(start) && now.isBefore(end)) return new Instant[]{ start, end };
        }
        return null;
    }
    public State state(Instant now, ZoneId zone, long elapsed, long overrideExpiry) {
        if (!enabled) return State.DISABLED;
        if (intervalContaining(now, zone) != null)
            return overrideExpiry > elapsed ? State.TEMPORARY_OVERRIDE : State.NIGHT_LOCK_ACTIVE;
        Instant start = nextStart(now, zone);
        return Duration.between(now, start).getSeconds() <= 1200 ? State.PRE_LOCK_WARNING : State.DAY_ACTIVE;
    }
    public Instant nextStart(Instant now, ZoneId zone) {
        LocalDate day = now.atZone(zone).toLocalDate();
        for (int i = 0; i <= 2; i++) {
            Instant start = at(day.plusDays(i), startMinute, zone).toInstant();
            if (start.isAfter(now)) return start;
        }
        throw new IllegalStateException("No schedule boundary");
    }
    public Instant nextBoundary(Instant now, ZoneId zone, boolean warnings) {
        List<Instant> candidates = new ArrayList<>();
        LocalDate day = now.atZone(zone).toLocalDate();
        for (int i = -1; i <= 2; i++) {
            Instant start = at(day.plusDays(i), startMinute, zone).toInstant();
            candidates.add(start);
            candidates.add(at(day.plusDays(i + (startMinute > endMinute ? 1 : 0)), endMinute, zone).toInstant());
            if (warnings) for (int m : new int[]{20,10,5}) candidates.add(start.minusSeconds(m * 60L));
        }
        return candidates.stream().filter(t -> t.isAfter(now)).min(Instant::compareTo).orElseThrow(IllegalStateException::new);
    }
}
