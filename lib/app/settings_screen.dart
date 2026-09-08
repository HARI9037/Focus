import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'controller.dart';
import 'screens.dart';

class SettingsScreen extends StatefulWidget {
  final FocusController c;const SettingsScreen({super.key,required this.c});
  @override State<SettingsScreen> createState()=>_SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  String? message;
  String timeLabel(int minute)=>'${(minute~/60).toString().padLeft(2,'0')}:${(minute%60).toString().padLeft(2,'0')}';
  Future<void> permission(String kind) async {
    final details=switch(kind){
      'accessibility'=>'Focus receives app-window change events, including the foreground package name, to show a restriction screen during your chosen hours. It does not read screen text, typed content, or passwords. Events are processed on this device and are not sent anywhere. You may disable this service in Android Settings at any time. This is a digital-discipline feature, not a disability accessibility tool.',
      'usage'=>'Focus reads Android app usage history to estimate time spent in each app. It stores daily app totals locally. No usage data is uploaded. You can revoke access in Android Settings.',
      'alarms'=>'Exact alarm access helps Night Lock reach schedule boundaries while the phone is idle. Without it, Android may delay warnings and schedule wakeups.',
      _=>'Notifications provide Night Lock warnings before your scheduled start. You may disable them at any time.'};
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text(kind=='accessibility'?'App-window access disclosure':'Enable $kind?'),content:Text(details),actions:[
      TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Not now')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('I agree · open settings'))]));
    if(yes==true){try{await widget.c.device.permission(kind);}catch(_){if(mounted)setState(()=>message='Could not open Android settings. Open the relevant permission page manually.');}}
  }
  Future<void> export(String extension)async{
    try{
      final text=extension=='json'?await widget.c.exportBackup():await widget.c.repository.exportCsv();
      if(Platform.isAndroid){await widget.c.device.export(text,extension);}else{
        final location=await getSaveLocation(suggestedName:'focus-export.$extension');if(location==null)return;
        await File(location.path).writeAsString(text,flush:true);
      }
      if(mounted)setState(()=>message='Export saved. Keep this file private; exports are not encrypted.');
    }catch(_){if(mounted)setState(()=>message='Export was cancelled or could not be saved.');}
  }
  Future<void> importBackup()async{
    final file=await openFile(acceptedTypeGroups:[const XTypeGroup(label:'Focus JSON backup',extensions:['json'],mimeTypes:['application/json'])]);
    if(file==null||!mounted)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Merge records from this backup?'),content:const Text('Newer records with the same ID replace older records, including deletions. Phone usage and settings are not restored in this version. Export a current backup first.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Merge records'))]));
    if(yes==true){await widget.c.run(()async{if(await file.length()>20*1024*1024)throw const FormatException('Too large');await widget.c.repository.importJson(await file.readAsString());});}
  }
  Future<void> whitelist()async{
    try{
      final apps=await widget.c.device.apps();if(!mounted)return;
      final chosen=Set<String>.from(widget.c.phone['whitelist'] as List? ?? []);
      final result=await showDialog<Set<String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(title:const Text('Essential apps'),
        content:SizedBox(width:480,height:420,child:ListView(children:[const Text('Select only the apps you need overnight. Phone and system safety surfaces remain available.'),
          for(final app in apps)CheckboxListTile(value:chosen.contains(app['package']),title:Text(app['label'] as String),subtitle:Text(app['package'] as String),
            onChanged:(v)=>update((){if(v==true){chosen.add(app['package'] as String);}else{chosen.remove(app['package']);}}))])),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,chosen),child:const Text('Save whitelist'))])));
      if(result!=null)await widget.c.configureNight({'whitelist':result.toList()});
    }catch(_){if(mounted)setState(()=>message='Could not load the available apps.');}
  }
  @override Widget build(BuildContext context){
    final c=widget.c;final p=c.phone;final native=c.device.supported;
    final start=(p['startMinute'] as num? ?? c.settings['startMinute'] as num? ?? 1260).toInt();
    final end=(p['endMinute'] as num? ?? c.settings['endMinute'] as num? ?? 420).toInt();
    return PageBody(eyebrow:'Make it yours',title:'Settings',children:[
      if(message!=null)Padding(padding:const EdgeInsets.only(bottom:24),child:Text(message!)),
      Section('Appearance',child:Wrap(spacing:8,children:[for(final m in ['system','light','dark'])ChoiceChip(label:Text(m),selected:(c.settings['theme']??'system')==m,onSelected:(_)=>c.set('theme',m))])),
      Section('Daily targets',child:Column(children:[ListTile(contentPadding:EdgeInsets.zero,title:const Text('Focus target'),subtitle:Text('${c.dailyFocusTarget} minutes'),trailing:DropdownButton<int>(value:[60,120,180,240,300].contains(c.dailyFocusTarget)?c.dailyFocusTarget:240,
        items:[for(final n in [60,120,180,240,300])DropdownMenuItem(value:n,child:Text('${n~/60}h'))],onChanged:(v){if(v!=null)c.set('focusTargetMinutes',v);})),
        ListTile(contentPadding:EdgeInsets.zero,title:const Text('Phone budget'),subtitle:Text('${c.phoneBudget} minutes'),trailing:DropdownButton<int>(value:[60,120,180,210,240,300].contains(c.phoneBudget)?c.phoneBudget:210,
        items:[for(final n in [60,120,180,210,240,300])DropdownMenuItem(value:n,child:Text('${n}m'))],onChanged:(v){if(v!=null)c.set('phoneBudgetMinutes',v);}))])),
      Section('Night Lock',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(native?'State: ${p['state']??'unavailable'}':'Android phone status unavailable · sync is not implemented.'),
        if(native)...[
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Enable schedule'),subtitle:Text('Night hours ${timeLabel(start)} → ${timeLabel(end)}'),value:p['enabled']==true,
            onChanged:c.busy?null:(v)=>c.configureNight({'enabled':v})),
          Wrap(spacing:12,children:[for(final item in [('startMinute','Start',start),('endMinute','End',end)])OutlinedButton(onPressed:()async{
            final t=await showTimePicker(context:context,initialTime:TimeOfDay(hour:item.$3~/60,minute:item.$3%60));
            if(t==null)return;final value=t.hour*60+t.minute;
            if(value==(item.$1=='startMinute'?end:start)){if(mounted)setState(()=>message='Start and end must differ.');return;}
            await c.configureNight({item.$1:value});},child:Text('${item.$2} ${timeLabel(item.$3)}')),
            OutlinedButton.icon(onPressed:whitelist,icon:const Icon(Icons.apps),label:const Text('Essential apps'))]),const SizedBox(height:16),
          Text('Restriction service: ${p['accessibility']==true?'connected':'not connected'} · Exact alarms: ${p['exactAlarms']==true?'allowed':'may be delayed'}'),
          const SizedBox(height:12),const Text('This is a voluntary software restriction. Android Settings, emergency communication, force-stop and uninstall remain available. Enabling the schedule alone does not connect the restriction service.'),
          ListTile(contentPadding:EdgeInsets.zero,title:const Text('Temporary access'),subtitle:const Text('Hold 10 seconds, choose a reason, confirm. Emergency access is immediate.'),
            trailing:DropdownButton<int>(value:(p['overrideMinutes'] as num? ?? 15).toInt(),items:[for(final n in [5,15,30])DropdownMenuItem(value:n,child:Text('${n}m'))],onChanged:(v){if(v!=null)c.configureNight({'overrideMinutes':v});})),
          SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Pre-lock warnings'),subtitle:const Text('20, 10 and 5 minutes before start; Android may defer delivery.'),value:p['warnings']!=false,onChanged:(v)=>c.configureNight({'warnings':v})),
          TextButton.icon(onPressed:()=>c.device.emergency(),icon:const Icon(Icons.phone_outlined),label:const Text('Immediate emergency / phone access')),
        ]else const Text('Night Lock enforcement is available only on Android. Windows is the planning workspace.'),
      ])),
      if(native)Section('Optional Android permissions',child:Column(children:[for(final item in [('usage','Usage Access',p['usageAccess']==true),('accessibility','Restriction service',p['accessibility']==true),('alarms','Exact alarms',p['exactAlarms']==true),('notifications','Notifications',p['notifications']==true)])
        ListTile(contentPadding:EdgeInsets.zero,title:Text(item.$2),subtitle:Text(item.$3?'Available':'Not enabled'),trailing:TextButton(onPressed:()=>permission(item.$1),child:const Text('Configure'))),
        TextButton(onPressed:c.refreshPhone,child:const Text('Refresh permission status'))])),
      if(native)Section('Recent override history',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        if((p['overrides'] as List? ?? []).isEmpty)const Text('No recorded overrides.'),
        for(final event in (p['overrides'] as List? ?? []).reversed.take(10))Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Text('${DateTime.fromMillisecondsSinceEpoch((event['startedAt'] as num).toInt()).toLocal()} · ${event['reason']} · ${event['status']}')),
        const Text('Native history retains the most recent 200 overrides. Continuous overnight compliance is not yet measured.'),
      ])),
      Section('Data & privacy',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Stored in this device’s private application directory. No account, AI, telemetry or cloud sync. Database-level encryption is not yet implemented. OS device encryption provides the current protection.'),const SizedBox(height:16),
        Wrap(spacing:12,runSpacing:12,children:[OutlinedButton(onPressed:()=>export('json'),child:const Text('Export JSON backup')),OutlinedButton(onPressed:()=>export('csv'),child:const Text('Export records CSV')),TextButton(onPressed:importBackup,child:const Text('Merge records from backup'))]),
      ])),
      const Section('About Focus 0.1',child:Text('Development source release. Android lifecycle and Windows builds require verification before relying on this app overnight. Planned: daytime blocking, richer analytics, full backup restore, authenticated cross-device sync and optional AI.')),
    ]);
  }
}
