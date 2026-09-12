package com.personal.focus;

import java.util.List;
import java.util.Map;
import java.util.Set;

/** Pure package-identity policy. A zero budget disables that budget. */
public final class DisciplinePolicy {
    public static final class Rule {
        public final String id, label;
        public final Set<String> packages;
        public final long budgetMs, blockedUntil;
        public final boolean duringFocus;
        public Rule(String id, String label, Set<String> packages, long budgetMs, long blockedUntil, boolean duringFocus) {
            if (budgetMs < 0 || budgetMs > 86400000L) throw new IllegalArgumentException("Invalid budget");
            this.id=id; this.label=label; this.packages=packages; this.budgetMs=budgetMs;
            this.blockedUntil=blockedUntil; this.duringFocus=duringFocus;
        }
    }
    public static final class Decision {
        public String reason = "";
        public long until = 0, nextCheckMs = Long.MAX_VALUE;
        public String warning = "", warningId = "";
        public boolean blocked() { return !reason.isEmpty(); }
    }
    public static Decision evaluate(String foreground, List<Rule> rules, Map<String,Long> usage,
            long now, long midnight, boolean focusing, long focusEnd, boolean hasUsage) {
        Decision result = new Decision();
        for (Rule rule : rules) {
            if (!rule.packages.contains(foreground)) continue;
            if (rule.blockedUntil > now) { result.reason=rule.label+" · cooldown"; result.until=rule.blockedUntil; return result; }
            if (focusing && rule.duringFocus) { result.reason="Focus session · "+rule.label; result.until=focusEnd; return result; }
            if (!hasUsage || rule.budgetMs == 0) continue;
            long used=0;
            for (String pkg:rule.packages) used+=Math.max(0,usage.getOrDefault(pkg,0L));
            long remaining=rule.budgetMs-used;
            if (remaining<=0) { result.reason=rule.label+" · daily limit reached"; result.until=midnight; return result; }
            long warningAt=rule.budgetMs*4/5;
            if (used>=warningAt) { result.warning=rule.label; result.warningId=rule.id; }
            result.nextCheckMs=Math.min(result.nextCheckMs,used<warningAt?warningAt-used:remaining);
        }
        return result;
    }
}
