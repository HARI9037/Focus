package com.personal.focus

import android.Manifest
import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity:FlutterActivity() {
    private val worker=Executors.newSingleThreadExecutor()
    private var exportResult:MethodChannel.Result?=null
    private var exportContent:String?=null
    override fun configureFlutterEngine(flutterEngine:FlutterEngine){
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"com.personal.focus/device").setMethodCallHandler{call,result->
            try{
                when(call.method){
                    "status"->{val store=NightStore(this);result.success(mapOf(
                        "supported" to true,"state" to store.state().name,"enabled" to store.policy().enabled,
                        "startMinute" to store.policy().startMinute,"endMinute" to store.policy().endMinute,
                        "overrideMinutes" to store.prefs.getInt("overrideMinutes",15),"warnings" to store.prefs.getBoolean("warnings",true),
                        "whitelist" to store.whitelist().toList(),"usageAccess" to usageAccess(),
                        "accessibility" to (FocusAccessibilityService.instance!=null),
                        "exactAlarms" to (Build.VERSION.SDK_INT<31||getSystemService(AlarmManager::class.java).canScheduleExactAlarms()),
                        "notifications" to getSystemService(NotificationManager::class.java).areNotificationsEnabled(),
                        "overrides" to store.overrides().let{array->(0 until array.length()).map{i->
                            val obj=array.getJSONObject(i);obj.keys().asSequence().associateWith{key->obj.get(key).let{if(it==JSONObject.NULL)null else it}}
                        }}
                    ))}
                    "configure"->{NightStore(this).configure(call.arguments as Map<*,*>);NightScheduler.schedule(this);FocusAccessibilityService.instance?.configurationChanged();result.success(null)}
                    "permission"->{
                        val kind=call.argument<String>("kind")
                        if(kind=="notifications"&&Build.VERSION.SDK_INT>=33){requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),22);result.success(null)}
                        else{
                            val intent=when(kind){
                                "usage"->Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                "accessibility"->{NightStore(this).prefs.edit().putBoolean("accessibilityConsent",true).commit();Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)}
                                "alarms"->if(Build.VERSION.SDK_INT>=31)Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,Uri.parse("package:$packageName"))else Intent(Settings.ACTION_SETTINGS)
                                else->Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE,packageName)
                            };startActivity(intent);result.success(null)
                        }
                    }
                    "apps"->{val intent=Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
                        val apps=packageManager.queryIntentActivities(intent,0).distinctBy{it.activityInfo.packageName}.map{
                            mapOf("package" to it.activityInfo.packageName,"label" to it.loadLabel(packageManager).toString())
                        }.sortedBy{it["label"]};result.success(apps)}
                    "usage"->{
                        val start=call.argument<Number>("start")?.toLong()?:0
                        val end=call.argument<Number>("end")?.toLong()?:0
                        require(start>0&&end>start&&end-start<=2*86400000L)
                        if(!usageAccess()){result.error("permission_missing","Usage Access is unavailable",null)}else{
                            worker.execute{try{val rows=usage(start,end);runOnUiThread{result.success(rows)}}
                                catch(_:Exception){runOnUiThread{result.error("usage_unavailable","Usage could not be read",null)}}}
                        }
                    }
                    "emergency"->{
                        try{NightStore(this).beginOverride("Emergency",true)}catch(_:Exception){}
                        FocusAccessibilityService.instance?.grantEmergencyEscape()
                        try{startActivity(Intent(Intent.ACTION_DIAL))}catch(_:Exception){startActivity(Intent(Settings.ACTION_SETTINGS))}
                        NightScheduler.schedule(this);result.success(null)
                    }
                    "export"->{
                        check(exportResult==null)
                        val extension=call.argument<String>("extension")?:"json";require(extension in listOf("json","csv"))
                        exportContent=call.argument<String>("content")?:"";exportResult=result
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).addCategory(Intent.CATEGORY_OPENABLE)
                            .setType(if(extension=="json")"application/json" else "text/csv")
                            .putExtra(Intent.EXTRA_TITLE,"focus-export.$extension"),42)
                    }
                    else->result.notImplemented()
                }
            }catch(_:Exception){result.error("operation_failed","Android could not complete this action",null)}
        }
        NightScheduler.schedule(this)
    }
    private fun usageAccess():Boolean {
        val ops=getSystemService(AppOpsManager::class.java)
        val mode=if(Build.VERSION.SDK_INT>=29)ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),packageName)
            else ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),packageName)
        return mode==AppOpsManager.MODE_ALLOWED
    }
    private fun usage(start:Long,end:Long):List<Map<String,Any>> {
        val manager=getSystemService(UsageStatsManager::class.java)
        // Bounded event replay; no continuously polling service. One-day lookback
        // can reconstruct a foreground session crossing midnight.
        val events=manager.queryEvents((start-86400000L).coerceAtLeast(0),end)?:return emptyList()
        val accumulator=UsageAccumulator(start,end);val event=UsageEvents.Event()
        while(events.hasNextEvent()){
            events.getNextEvent(event)
            accumulator.event(event.timeStamp,event.packageName,event.eventType)
        }
        return accumulator.finish().entries.map{(pkg,ms)->
            val label=try{packageManager.getApplicationLabel(packageManager.getApplicationInfo(pkg,0)).toString()}catch(_:Exception){pkg}
            mapOf("package" to pkg,"label" to label,"milliseconds" to ms)
        }.sortedByDescending{it["milliseconds"] as Long}
    }
    @Deprecated("Activity result bridge retained for FlutterActivity compatibility")
    override fun onActivityResult(requestCode:Int,resultCode:Int,data:Intent?){
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode!=42)return
        val result=exportResult?:return;val content=exportContent?:"";exportResult=null;exportContent=null
        if(resultCode!=RESULT_OK||data?.data==null){result.error("cancelled","Export cancelled",null);return}
        val uri=data.data!!
        worker.execute{try{
            val stream=contentResolver.openOutputStream(uri,"wt")?:error("No destination")
            stream.bufferedWriter().use{it.write(content)};runOnUiThread{result.success(null)}
        }catch(_:Exception){runOnUiThread{result.error("export_failed","Export could not be saved",null)}}}
    }
    override fun onDestroy(){exportResult?.error("interrupted","Export interrupted",null);exportResult=null;worker.shutdown();super.onDestroy()}
}
