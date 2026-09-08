import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'editor.dart';
import '../features/tasks/domain/entry.dart';
import '../features/analytics/domain/analytics.dart';

String durationLabel(int seconds) => seconds<3600?'${seconds~/60}m':'${seconds~/3600}h ${(seconds%3600)~/60}m';
class PageBody extends StatelessWidget {
  final String eyebrow,title;
  final List<Widget> children;
  final Widget? action;
  const PageBody({super.key,required this.title,this.eyebrow='',required this.children,this.action});
  @override Widget build(BuildContext context)=>ListView(padding:EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width>950?40:20,20,MediaQuery.sizeOf(context).width>950?40:20,40),children:[
    if(eyebrow.isNotEmpty)...[Text(eyebrow.toUpperCase(),style:TextStyle(fontSize:11,letterSpacing:2,color:Theme.of(context).colorScheme.primary)),const SizedBox(height:12)],
    Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,spacing:24,runSpacing:12,children:[Text(title,style:Theme.of(context).textTheme.headlineLarge),if(action!=null)action!]),
    const SizedBox(height:32),...children]);
}
class Section extends StatelessWidget {
  final String title;
  final Widget child;
  const Section(this.title,{super.key,required this.child});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:28),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),child]));
}
class EmptyState extends StatelessWidget {
  final String title,detail;
  const EmptyState(this.title,this.detail,{super.key});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:30),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:6),Text(detail,style:Theme.of(context).textTheme.bodyMedium)]));
}
class EntryTile extends StatelessWidget {
  final FocusController c;final Entry e;
  const EntryTile({super.key,required this.c,required this.e});
  @override Widget build(BuildContext context) {
    final done=e.state=='completed';
    final sub=[if(e.dueAt!=null)DateFormat('MMM d · HH:mm').format(e.dueAt!.toLocal()),e.state.replaceAll('_',' '),
      if(e.priority>=2)['Low','Medium','High','Critical'][e.priority]];
    return Column(children:[ListTile(contentPadding:EdgeInsets.zero,
      leading:e.kind=='task'?Checkbox(value:done,onChanged:c.busy||done?null:(v)=>c.complete(e)):Icon(switch(e.kind){'project'=>Icons.work_outline,'note'=>Icons.notes,'habit'=>Icons.spa_outlined,'goal'=>Icons.flag_outlined,_=>Icons.circle_outlined}),
      title:Text(e.title,style:TextStyle(decoration:done?TextDecoration.lineThrough:null)),subtitle:Text(sub.join(' · ')),
      onTap:()=>editEntry(context,c,entry:e),trailing:PopupMenuButton<String>(onSelected:(v)async{
        if(v=='edit'){editEntry(context,c,entry:e);return;}
        final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Delete this item?'),content:Text(e.title),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
        if(yes==true)await c.remove(e);
      },itemBuilder:(_)=>const[PopupMenuItem(value:'edit',child:Text('Edit')),PopupMenuItem(value:'delete',child:Text('Delete'))])),const Divider(height:1)]);
  }
}
class TodayScreen extends StatelessWidget {
  final FocusController c;final ValueChanged<int> onNavigate;
  const TodayScreen({super.key,required this.c,required this.onNavigate});
  @override Widget build(BuildContext context){
    final now=DateTime.now(),today=DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
    final tomorrow=DateTime(today.year,today.month,today.day+1);
    final tasks=c.of('task').where((e)=>e.state!='completed'&&e.state!='cancelled'&&
      (e.dueAt!=null&&e.dueAt!.isBefore(tomorrow)||e.state=='in_progress'||e.state=='planned')).toList();
    tasks.sort((a,b)=>b.priority.compareTo(a.priority));
    final seconds=AnalyticsEngine.focusSeconds(c.entries,today,tomorrow);
    final usage=c.usage.where((r)=>r['day']==dayKey(today)).toList();
    final total=usage.fold<int>(0,(a,r)=>a+(r['milliseconds'] as int))~/1000;
    return PageBody(eyebrow:DateFormat('EEEE, MMMM d').format(now),title:now.hour<12?'A fresh start.':now.hour<18?'Make room for focus.':'Bring the day to a close.',
      action:OutlinedButton.icon(onPressed:()=>editEntry(context,c),icon:const Icon(Icons.add,size:18),label:const Text('Quick capture')),children:[
      const Text('One thing at a time. Start with what matters most.',style:TextStyle(fontSize:17)),const SizedBox(height:36),
      Section('Your priorities',child:tasks.isEmpty?const EmptyState('A little space to think.','Capture a task, then plan it or give it a due date.'):Column(children:[for(final e in tasks.take(3))EntryTile(c:c,e:e)])),
      Container(padding:const EdgeInsets.symmetric(vertical:28),decoration:const BoxDecoration(border:Border(top:BorderSide(color:Colors.grey,width:.3),bottom:BorderSide(color:Colors.grey,width:.3))),
        child:Wrap(spacing:56,runSpacing:24,crossAxisAlignment:WrapCrossAlignment.center,children:[Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('FOCUS TODAY',style:TextStyle(fontSize:11,letterSpacing:2)),const SizedBox(height:10),Text(durationLabel(seconds),style:Theme.of(context).textTheme.headlineLarge),Text('of ${durationLabel(c.dailyFocusTarget*60)} planned')]),
          FilledButton.icon(onPressed:()=>onNavigate(5),icon:Icon(c.activeSession==null?Icons.play_arrow:Icons.timelapse),label:Text(c.activeSession==null?'Start focus':'Return to session'))])),const SizedBox(height:30),
      Section('Phone budget',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(usage.isEmpty?'Usage unavailable':
        '${durationLabel(total)} used · ${durationLabel((c.phoneBudget*60-total).clamp(0,c.phoneBudget*60).toInt())} remaining',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:12),
        if(usage.isNotEmpty)LinearProgressIndicator(value:(total/(c.phoneBudget*60)).clamp(0,1).toDouble(),minHeight:4),const SizedBox(height:8),
        Text(c.device.supported?'Update phone usage in Analytics. Values are OS estimates.':'Connect phone sync in a future release to see Android usage here.')])),
      Section('Coming up',child:Column(children:[for(final e in c.entries.where((e)=>e.dueAt!=null&&e.dueAt!.isAfter(now)&&e.state!='completed').take(4))EntryTile(c:c,e:e)])),
    ]);
  }
}
class RecordsScreen extends StatefulWidget {
  final FocusController c;final String kind;
  const RecordsScreen({super.key,required this.c,required this.kind});
  @override State<RecordsScreen> createState()=>_RecordsScreenState();
}
class _RecordsScreenState extends State<RecordsScreen> {
  String filter='active';
  @override Widget build(BuildContext context){
    final c=widget.c,kind=widget.kind;
    final rows=c.entries.where((e)=>kind=='inbox'?(e.kind=='task'&&e.state=='inbox'||e.kind=='idea'||e.kind=='reminder'):
      kind=='note'?(e.kind=='note'||e.kind=='idea'):e.kind==kind).where((e)=>filter=='all'||!['completed','archived','cancelled'].contains(e.state)).toList();
    if(kind=='note')rows.sort((a,b)=>(b.data['pinned']==true?1:0).compareTo(a.data['pinned']==true?1:0));
    return PageBody(eyebrow:'Your workspace',title:kind=='inbox'?'Inbox':kind=='habit'?'Habits':kind=='goal'?'Goals':kind=='note'?'Notes':kind=='project'?'Projects':'Tasks',
      action:FilledButton.icon(onPressed:()=>editEntry(context,c,kind:kind=='inbox'?'task':kind),icon:const Icon(Icons.add),label:const Text('New')),children:[
        Row(children:[ChoiceChip(label:const Text('Active'),selected:filter=='active',onSelected:(_)=>setState(()=>filter='active')),const SizedBox(width:8),
          ChoiceChip(label:const Text('All'),selected:filter=='all',onSelected:(_)=>setState(()=>filter='all'))]),const SizedBox(height:20),
        if(rows.isEmpty)const EmptyState('Your next idea starts here.','Use New or the + button to capture it.'),
        for(final e in rows)...[
          EntryTile(c:c,e:e),
          if(kind=='project')Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            LinearProgressIndicator(value:projectProgress(c.entries,e.id),minHeight:4),const SizedBox(height:8),Text('${(projectProgress(c.entries,e.id)*100).round()}% of linked tasks complete'),
            if(e.body.isNotEmpty)Text(e.body,maxLines:3,overflow:TextOverflow.ellipsis),
            for(final task in c.of('task').where((t)=>t.projectId==e.id).take(5))EntryTile(c:c,e:task)])),
          if(kind=='note')Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(e.body.isEmpty?'No content yet.':e.body,maxLines:6,overflow:TextOverflow.ellipsis)),
            IconButton(tooltip:'Pin note',icon:Icon(e.data['pinned']==true?Icons.push_pin:Icons.push_pin_outlined),onPressed:()=>c.save(e.copy(data:{...e.data,'pinned':e.data['pinned']!=true})))])),
          if(kind=='goal')Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            LinearProgressIndicator(value:((e.data['current'] as num? ?? 0)/(e.data['target'] as num? ?? 1)).clamp(0,1).toDouble()),const SizedBox(height:8),
            Text('${e.data['current']??0} / ${e.data['target']??1} ${e.data['unit']??''} · manually tracked')])),
          if(kind=='habit')Builder(builder:(ctx){final days=Set<String>.from(e.data['days'] as List? ?? []);return Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Wrap(spacing:20,crossAxisAlignment:WrapCrossAlignment.center,children:[
            FilterChip(selected:days.contains(dayKey(DateTime.now())),label:const Text('Done today'),onSelected:(_)=>c.toggleHabit(e)),
            Text('${AnalyticsEngine.streak(days,DateTime.now())} day streak · best ${AnalyticsEngine.longestStreak(days)}')]));}),
        ]]);
  }
}
class CalendarScreen extends StatefulWidget {
  final FocusController c;const CalendarScreen({super.key,required this.c});
  @override State<CalendarScreen> createState()=>_CalendarScreenState();
}
class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected=DateTime.now();String mode='Week';
  @override Widget build(BuildContext context){
    final d=DateTime(selected.year,selected.month,selected.day);
    final start=mode=='Month'?DateTime(d.year,d.month):mode=='Week'?DateTime(d.year,d.month,d.day-d.weekday+1):d;
    final count=mode=='Month'?DateTime(d.year,d.month+1,0).day:mode=='Week'?7:1;
    return PageBody(eyebrow:'A little structure',title:'Calendar',children:[Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
      for(final m in ['Day','Week','Month'])ChoiceChip(label:Text(m),selected:mode==m,onSelected:(_)=>setState(()=>mode=m)),
      IconButton(tooltip:'Previous period',onPressed:()=>setState(()=>selected=mode=='Month'?DateTime(d.year,d.month-1):DateTime(d.year,d.month,d.day-count)),icon:const Icon(Icons.chevron_left)),
      Text(DateFormat('MMMM y').format(start)),IconButton(tooltip:'Next period',onPressed:()=>setState(()=>selected=mode=='Month'?DateTime(d.year,d.month+1):DateTime(d.year,d.month,d.day+count)),icon:const Icon(Icons.chevron_right)),
      TextButton(onPressed:()=>setState(()=>selected=DateTime.now()),child:const Text('Today'))]),const SizedBox(height:24),
      for(var i=0;i<count;i++)Builder(builder:(context){final day=DateTime(start.year,start.month,start.day+i);
        final list=widget.c.entries.where((e)=>(e.dueAt!=null&&dayKey(e.dueAt!)==dayKey(day))||
          (e.kind=='session'&&e.data['startedAt']!=null&&dayKey(DateTime.parse(e.data['startedAt'] as String))==dayKey(day))).toList();
        list.sort((a,b)=>(a.dueAt??a.createdAt).compareTo(b.dueAt??b.createdAt));
        return Section(DateFormat('EEE, MMM d').format(day),child:list.isEmpty?const Text('Open space'):Column(children:[for(final e in list)e.kind=='session'?
          ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.timelapse),title:Text(e.title),subtitle:Text('Focus · ${e.state}')):EntryTile(c:widget.c,e:e)]));}),
    ]);
  }
}
class FocusScreen extends StatefulWidget {
  final FocusController c;const FocusScreen({super.key,required this.c});
  @override State<FocusScreen> createState()=>_FocusScreenState();
}
class _FocusScreenState extends State<FocusScreen> {
  int minutes=50;String? task;
  @override Widget build(BuildContext context){
    final c=widget.c,s=c.activeSession;
    var seconds=minutes*60;
    if(s!=null){final start=DateTime.parse(s.data['startedAt'] as String),end=DateTime.tryParse(s.data['targetEnd'] as String? ?? '');
      seconds=end==null?DateTime.now().difference(start).inSeconds:end.difference(DateTime.now()).inSeconds;seconds=seconds.clamp(0,999999).toInt();}
    final timer='${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}';
    return PageBody(eyebrow:'Protect your attention',title:'Focus',children:[
      Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:550),child:Column(children:[const SizedBox(height:24),
        Text(s?.title??'Choose one meaningful thing.',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:32),
        FittedBox(child:Text(timer,style:const TextStyle(fontSize:96,fontWeight:FontWeight.w300,letterSpacing:-4,fontFeatures:[FontFeature.tabularFigures()]))),
        const SizedBox(height:24),if(s==null)...[
          Wrap(spacing:8,runSpacing:8,alignment:WrapAlignment.center,children:[for(final n in [25,50,90,0])ChoiceChip(label:Text(n==0?'Open ended':'$n min'),selected:minutes==n,onSelected:(_)=>setState(()=>minutes=n))]),
          TextButton(onPressed:()async{final input=TextEditingController(text:'$minutes');final n=await showDialog<int>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Custom focus duration'),content:TextField(controller:input,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Minutes (1–240)')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:(){final v=int.tryParse(input.text);if(v!=null&&v>0&&v<=240)Navigator.pop(ctx,v);},child:const Text('Set'))]));input.dispose();if(n!=null&&mounted)setState(()=>minutes=n);},child:const Text('Custom duration')),
          const SizedBox(height:16),DropdownButtonFormField<String>(value:c.of('task').any((e)=>e.id==task&&e.state!='completed')?task:null,decoration:const InputDecoration(labelText:'Link a task'),
            items:[const DropdownMenuItem<String>(value:null,child:Text('Unlinked deep work')),for(final e in c.of('task').where((e)=>e.state!='completed'))DropdownMenuItem(value:e.id,child:Text(e.title,overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>task=v)),
          const SizedBox(height:24),FilledButton.icon(onPressed:c.busy?null:()=>c.startSession(minutes,task),icon:const Icon(Icons.play_arrow),label:const Text('Begin focus')),
        ]else...[
          const Text('Your session is saved. You can return to it after reopening Focus.'),const SizedBox(height:20),
          OutlinedButton(onPressed:c.busy?null:()=>c.finishSession(completed:false),child:const Text('End session early')),
        ],const SizedBox(height:24),const Text('Distraction blocking and background completion notifications are planned. The session timer records elapsed time; it does not infer attention.',textAlign:TextAlign.center),
      ]))),const SizedBox(height:48),Section('Recent sessions',child:Column(children:[for(final e in c.of('session').where((e)=>e.state!='active').take(12))ListTile(contentPadding:EdgeInsets.zero,
        leading:Icon(e.state=='completed'?Icons.check_circle_outline:Icons.timelapse),title:Text(e.title),subtitle:Text('${durationLabel((e.data['actualSeconds'] as num? ?? 0).toInt())} · ${e.state} · ${DateFormat('MMM d').format(e.createdAt.toLocal())}'))])),
    ]);
  }
}
class AnalyticsScreen extends StatefulWidget {
  final FocusController c;const AnalyticsScreen({super.key,required this.c});
  @override State<AnalyticsScreen> createState()=>_AnalyticsScreenState();
}
class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int length=7;
  @override Widget build(BuildContext context){
    final c=widget.c,now=DateTime.now();final today=DateTime(now.year,now.month,now.day);
    final end=DateTime(today.year,today.month,today.day+1),start=DateTime(today.year,today.month,today.day-length+1);
    final tasks=c.of('task').where((e)=>e.dueAt!=null&&!e.dueAt!.isBefore(start)&&e.dueAt!.isBefore(end)&&e.state!='cancelled').toList();
    final completed=tasks.where((e)=>e.state=='completed').length;
    final seconds=AnalyticsEngine.focusSeconds(c.entries,start,end);
    final score=AnalyticsEngine.productivity(completed:completed,planned:tasks.length,focusSeconds:seconds,targetSeconds:c.dailyFocusTarget*60*length);
    final usage=c.usage.where((r)=>(r['day'] as String).compareTo(dayKey(start))>=0&&(r['day'] as String).compareTo(dayKey(end))<0).toList();
    final observed=usage.map((r)=>r['day']).toSet().length;
    final usageSeconds=usage.fold<int>(0,(s,r)=>s+(r['milliseconds'] as int))~/1000;
    final discipline=AnalyticsEngine.discipline(usageSeconds:observed==0?null:usageSeconds,budgetSeconds:c.phoneBudget*60*observed);
    final byApp=<String,int>{};for(final r in usage){final label=r['label'] as String;byApp[label]=(byApp[label]??0)+(r['milliseconds'] as int);}
    final apps=byApp.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
    final focusDays=[for(var i=0;i<length;i++)AnalyticsEngine.focusSeconds(c.entries,DateTime(start.year,start.month,start.day+i),DateTime(start.year,start.month,start.day+i+1)).toDouble()];
    return PageBody(eyebrow:'Understand your patterns',title:'Analytics',action:c.device.supported?OutlinedButton.icon(onPressed:c.busy?null:()=>c.refreshUsage(),icon:const Icon(Icons.refresh),label:const Text('Update phone usage')):null,children:[
      Wrap(spacing:8,runSpacing:8,children:[for(final n in [1,7,30])ChoiceChip(label:Text(n==1?'Today':n==7?'Last 7 days':'Last 30 days'),selected:length==n,onSelected:(_)=>setState(()=>length=n))]),const SizedBox(height:24),
      Wrap(spacing:50,runSpacing:24,children:[_metric(context,'FOCUS TIME',durationLabel(seconds)),_metric(context,'PLANNED TASKS','$completed / ${tasks.length}'),_metric(context,'PHONE USAGE',observed==0?'—':durationLabel(usageSeconds))]),const SizedBox(height:32),
      Section('Focus over time',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(height:170,child:LayoutBuilder(builder:(ctx,box){final max=focusDays.fold<double>(1,(a,b)=>a>b?a:b);return Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
        for(var i=0;i<length;i++)Expanded(child:Tooltip(message:'${DateFormat('MMM d').format(DateTime(start.year,start.month,start.day+i))}: ${durationLabel(focusDays[i].toInt())}',child:Semantics(label:'${dayKey(DateTime(start.year,start.month,start.day+i))}, ${durationLabel(focusDays[i].toInt())}',child:Padding(padding:const EdgeInsets.symmetric(horizontal:3),child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[
          Container(height:(focusDays[i]/max*135).clamp(2,135).toDouble(),decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary.withValues(alpha:focusDays[i]==0?.15:.85),borderRadius:const BorderRadius.vertical(top:Radius.circular(3)))),
          if(length<=7)...[const SizedBox(height:8),Text(DateFormat('E').format(DateTime(start.year,start.month,start.day+i)),style:const TextStyle(fontSize:10))]])))))]);})),
        const SizedBox(height:10),const Text('Hover or long-press a bar for the daily total. Active sessions are excluded until saved.')])),
      Section('Most-used apps',child:observed==0?const EmptyState('No observed phone data yet.','On Android, enable Usage Access in Settings, then update usage. Windows phone sync is not implemented.'):Column(children:[
        for(final app in apps.take(8))Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[Expanded(child:Text(app.key)),Text(durationLabel(app.value~/1000))])),
        Text('$observed of $length days have imported OS data. App foreground totals are estimates and may overlap with multi-window use. Missing days are not zero-use days.'),
      ])),
      Section('Productivity score',child:_score(context,score)),
      Section('Digital discipline score',child:_score(context,discipline)),
      const Section('What the data can tell you',child:Text('Scores describe these recorded targets, not your worth or health. Night Lock compliance stays unavailable until continuous enforcement observation is implemented. Comparisons and correlations need enough comparable observations; no causal claim is made.')),
    ]);
  }
  Widget _metric(BuildContext context,String label,String value)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:10,letterSpacing:1.7)),const SizedBox(height:10),Text(value,style:Theme.of(context).textTheme.headlineMedium)]);
  Widget _score(BuildContext context,ExplainedScore score)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(score.value==null?'Unavailable':'${score.value!.round()} / 100',style:Theme.of(context).textTheme.headlineMedium),const SizedBox(height:8),
    Text('${(score.coverage*100).round()}% component coverage. Available weights are renormalized.'),const SizedBox(height:12),
    for(final p in score.parts)Padding(padding:const EdgeInsets.only(bottom:8),child:Text('${p.name}: ${p.value==null?'unavailable':'${(p.value!.clamp(0,1)*100).round()}%'} · weight ${(p.weight*100).round()}%'))]);
}
class SearchScreen extends StatelessWidget {
  final FocusController c;final String query;
  const SearchScreen({super.key,required this.c,required this.query});
  @override Widget build(BuildContext context){final q=query.toLowerCase();final rows=c.entries.where((e)=>['task','project','note','idea','goal'].contains(e.kind)&&('${e.title} ${e.body} ${e.data['tags']??''}').toLowerCase().contains(q)).toList();
    return PageBody(title:'Search',eyebrow:'${rows.length} results',children:[if(rows.isEmpty)const EmptyState('No matches.','Try a title, note phrase or tag.'),for(final e in rows)EntryTile(c:c,e:e)]);}
}
