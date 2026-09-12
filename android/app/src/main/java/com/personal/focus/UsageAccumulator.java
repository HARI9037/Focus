package com.personal.focus;
import java.util.*;

/** Exclusive foreground estimate from ordered UsageEvents, not physical screen time.
 * Window can start before the requested range to reconstruct an already-open app. */
public final class UsageAccumulator {
    private final long start, end;
    private String active;
    private long since;
    private final Map<String, Long> totals = new HashMap<>();
    public UsageAccumulator(long start, long end) {
        if (end <= start) throw new IllegalArgumentException("Invalid range");
        this.start=start; this.end=end;
    }
    private void close(long at) {
        if (active != null) {
            long duration = Math.max(0, Math.min(end,at)-Math.max(start,since));
            if (duration > 0) totals.merge(active,duration,Long::sum);
        }
        active=null;
    }
    public void event(long time, String pkg, int type) {
        if (time >= end) return;
        if (type == 1 && pkg != null) {
            if (pkg.equals(active)) return; // duplicate resume must not truncate time
            close(time); active=pkg; since=time;
        } else if (type == 2 && Objects.equals(active,pkg)) close(time);
        else if (type == 15 || type == 17 || type == 26) close(time); // screen off / keyguard / shutdown
    }
    public Map<String,Long> finish() { close(end); return new HashMap<>(totals); }
}
