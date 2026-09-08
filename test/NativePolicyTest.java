import com.personal.focus.NightPolicy;
import com.personal.focus.UsageAccumulator;
import java.time.*;
import java.util.*;

public class NativePolicyTest {
    static int checks=0;
    static final ZoneId UTC=ZoneId.of("UTC");
    static void eq(Object actual,Object expected,String message){checks++;if(!Objects.equals(actual,expected))throw new AssertionError(message+": "+actual+" != "+expected);}
    static Instant t(String text){return Instant.parse(text);}
    static NightPolicy.State state(NightPolicy p,String date){return p.state(t(date),UTC,10000,0);}
    public static void main(String[] args){
        NightPolicy p=new NightPolicy(1260,420,true);
        eq(state(p,"2026-09-08T20:39:59Z"),NightPolicy.State.DAY_ACTIVE,"before warnings");
        eq(state(p,"2026-09-08T20:40:00Z"),NightPolicy.State.PRE_LOCK_WARNING,"20 minute warning");
        eq(state(p,"2026-09-08T20:59:59Z"),NightPolicy.State.PRE_LOCK_WARNING,"last daylight second");
        eq(state(p,"2026-09-08T21:00:00Z"),NightPolicy.State.NIGHT_LOCK_ACTIVE,"inclusive start");
        eq(state(p,"2026-09-09T00:00:00Z"),NightPolicy.State.NIGHT_LOCK_ACTIVE,"midnight");
        eq(state(p,"2026-09-09T06:59:59Z"),NightPolicy.State.NIGHT_LOCK_ACTIVE,"before end");
        eq(state(p,"2026-09-09T07:00:00Z"),NightPolicy.State.DAY_ACTIVE,"exclusive end");
        eq(new NightPolicy(1260,420,false).state(t("2026-09-08T22:00:00Z"),UTC,0,0),NightPolicy.State.DISABLED,"disabled");
        eq(p.state(t("2026-09-08T22:00:00Z"),UTC,100,101),NightPolicy.State.TEMPORARY_OVERRIDE,"active override");
        eq(p.state(t("2026-09-08T22:00:00Z"),UTC,101,101),NightPolicy.State.NIGHT_LOCK_ACTIVE,"exact override expiry");
        eq(p.state(t("2026-09-08T18:00:00Z"),UTC,100,101),NightPolicy.State.DAY_ACTIVE,"override cannot lock daytime");
        NightPolicy daytime=new NightPolicy(600,720,true);
        eq(state(daytime,"2026-09-08T10:00:00Z"),NightPolicy.State.NIGHT_LOCK_ACTIVE,"same day schedule");
        eq(state(daytime,"2026-09-08T12:00:00Z"),NightPolicy.State.DAY_ACTIVE,"same day end");
        eq(p.nextBoundary(t("2026-09-08T20:00:00Z"),UTC,true),t("2026-09-08T20:40:00Z"),"warning boundary");
        eq(p.nextBoundary(t("2026-09-08T20:40:00Z"),UTC,true),t("2026-09-08T20:50:00Z"),"next warning");
        eq(p.nextBoundary(t("2026-09-08T20:50:00Z"),UTC,true),t("2026-09-08T20:55:00Z"),"five minute warning");
        eq(p.nextBoundary(t("2026-09-08T21:00:00Z"),UTC,true),t("2026-09-09T07:00:00Z"),"night end alarm");
        eq(p.nextBoundary(t("2026-09-08T20:00:00Z"),UTC,false),t("2026-09-08T21:00:00Z"),"warnings disabled");
        eq(p.state(t("2026-09-08T15:30:00Z"),ZoneId.of("Asia/Kolkata"),0,0),NightPolicy.State.NIGHT_LOCK_ACTIVE,"India local time");
        eq(p.state(t("2026-09-08T15:30:00Z"),UTC,0,0),NightPolicy.State.DAY_ACTIVE,"timezone change");
        ZoneId ny=ZoneId.of("America/New_York");
        Instant[] spring=p.intervalContaining(t("2026-03-08T06:30:00Z"),ny);
        eq(Duration.between(spring[0],spring[1]).toHours(),9L,"spring night is nine real hours");
        Instant[] fall=p.intervalContaining(t("2026-11-01T05:30:00Z"),ny);
        eq(Duration.between(fall[0],fall[1]).toHours(),11L,"fall night is eleven real hours");
        NightPolicy missingTime=new NightPolicy(150,420,true);
        eq(missingTime.state(t("2026-03-08T07:15:00Z"),ny,0,0),NightPolicy.State.PRE_LOCK_WARNING,"missing start shifts forward");
        eq(missingTime.state(t("2026-03-08T07:30:00Z"),ny,0,0),NightPolicy.State.NIGHT_LOCK_ACTIVE,"missing 02:30 resolves 03:30");
        NightPolicy repeatedEnd=new NightPolicy(1260,90,true);
        eq(repeatedEnd.state(t("2026-11-01T06:15:00Z"),ny,0,0),NightPolicy.State.DAY_ACTIVE,"fall overlap does not relock after earlier end");
        for(int[] bad:new int[][]{{0,0},{-1,420},{1440,420},{1260,1440}}){
            boolean caught=false;try{new NightPolicy(bad[0],bad[1],true);}catch(IllegalArgumentException e){caught=true;}eq(caught,true,"invalid config");
        }
        UsageAccumulator a=new UsageAccumulator(1000,5000);
        a.event(500,"a",1);a.event(2000,"b",1);a.event(3000,"b",2);
        eq(a.finish(),Map.of("a",1000L,"b",1000L),"clip crossing start and switch apps");
        UsageAccumulator duplicate=new UsageAccumulator(1000,5000);
        duplicate.event(1000,"a",1);duplicate.event(2000,"a",1);duplicate.event(3000,"a",2);
        eq(duplicate.finish(),Map.of("a",2000L),"duplicate resume");
        UsageAccumulator stalePause=new UsageAccumulator(1000,5000);
        stalePause.event(1000,"a",1);stalePause.event(2000,"b",1);stalePause.event(2500,"a",2);stalePause.event(4000,"b",2);
        eq(stalePause.finish(),Map.of("a",1000L,"b",2000L),"unrelated pause");
        UsageAccumulator screenOff=new UsageAccumulator(1000,5000);
        screenOff.event(1000,"a",1);screenOff.event(2000,null,15);
        eq(screenOff.finish(),Map.of("a",1000L),"screen off stops usage");
        UsageAccumulator ongoing=new UsageAccumulator(1000,5000);ongoing.event(4000,"a",1);
        eq(ongoing.finish(),Map.of("a",1000L),"clip ongoing event at range end");
        UsageAccumulator empty=new UsageAccumulator(1000,5000);eq(empty.finish(),Map.of(),"empty is not synthetic usage");
        // Exhaustive minute-of-day invariants across ordinary civil schedules.
        for(int start:new int[]{0,60,600,1260,1439})for(int end:new int[]{0,420,720,1439}){
            if(start==end)continue;NightPolicy policy=new NightPolicy(start,end,true);
            for(int minute=0;minute<1440;minute++){
                Instant instant=LocalDate.of(2026,9,8).atStartOfDay(UTC).toInstant().plusSeconds(minute*60L);
                boolean expected=start>end?minute>=start||minute<end:minute>=start&&minute<end;
                eq(policy.intervalContaining(instant,UTC)!=null,expected,"minute membership");
                eq(policy.nextBoundary(instant,UTC,true).isAfter(instant),true,"next alarm strictly future");
            }
        }
        System.out.println("PASS: "+checks+" native policy and usage assertions");
    }
}
