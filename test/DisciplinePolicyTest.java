import com.personal.focus.DisciplinePolicy;
import java.util.*;
public class DisciplinePolicyTest {
    static void check(boolean value){if(!value)throw new AssertionError();}
    public static void main(String[] args){
        var rule=new DisciplinePolicy.Rule("social","Social",Set.of("app.a","app.b"),10000,0,true);
        var rules=List.of(rule);
        var d=DisciplinePolicy.evaluate("app.a",rules,Map.of("app.a",4000L,"app.b",4000L),100,100000,false,0,true);
        check(!d.blocked() && d.nextCheckMs==2000 && !d.warning.isEmpty());
        check(DisciplinePolicy.evaluate("app.a",rules,Map.of("app.a",10000L),100,100000,false,0,true).blocked());
        check(!DisciplinePolicy.evaluate("app.c",rules,Map.of("app.a",10000L),100,100000,true,20000,true).blocked());
        check(!DisciplinePolicy.evaluate("app.a",rules,Map.of("app.a",10000L),100,100000,false,0,false).blocked());
        check(DisciplinePolicy.evaluate("app.a",rules,Map.of(),100,100000,true,20000,false).blocked());
        var cooldown=List.of(new DisciplinePolicy.Rule("x","Rest",Set.of("app.a"),0,200,false));
        check(DisciplinePolicy.evaluate("app.a",cooldown,Map.of(),199,100000,false,0,false).blocked());
        check(!DisciplinePolicy.evaluate("app.a",cooldown,Map.of(),200,100000,false,0,false).blocked());
        for(long used=0;used<12000;used++){
            d=DisciplinePolicy.evaluate("app.a",rules,Map.of("app.a",used),100,100000,false,0,true);
            check(d.blocked()==(used>=10000));
            if(used<8000)check(d.nextCheckMs==8000-used);
            else if(used<10000)check(d.nextCheckMs==10000-used);
        }
        System.out.println("PASS: discipline budget, group, warning, focus, cooldown, permission and boundary checks");
    }
}
