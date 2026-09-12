package com.personal.focus

import android.app.*
import android.content.*
import android.net.Uri
import android.os.Build
import org.json.JSONArray

object FocusEventScheduler {
    private fun pending(context:Context,id:String)=PendingIntent.getBroadcast(context,0,
        Intent(context,FocusEventReceiver::class.java).setData(Uri.parse("focus://event/$id")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun update(context:Context,raw:String){
        val entries=JSONArray(raw);require(entries.length()<=500)
        val prefs=context.getSharedPreferences("focus_events",Context.MODE_PRIVATE)
        val old=JSONArray(prefs.getString("events","[]"))
        val manager=context.getSystemService(AlarmManager::class.java)
        for(i in 0 until old.length())manager.cancel(pending(context,old.getJSONObject(i).getString("id")))
        check(prefs.edit().putString("events",raw).commit());schedule(context)
    }
    fun schedule(context:Context){
        val entries=JSONArray(context.getSharedPreferences("focus_events",Context.MODE_PRIVATE).getString("events","[]"))
        val manager=context.getSystemService(AlarmManager::class.java)
        for(i in 0 until entries.length()){
            val e=entries.getJSONObject(i);val at=e.getLong("at")
            if(at<=System.currentTimeMillis())continue
            val p=pending(context,e.getString("id"))
            try{if(Build.VERSION.SDK_INT<31 || manager.canScheduleExactAlarms())manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,p)
                else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,p)}
            catch(_:SecurityException){manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,at,p)}
        }
    }
}
class FocusEventReceiver:BroadcastReceiver(){
    override fun onReceive(context:Context,intent:Intent){
        try{
            val id=intent.data?.lastPathSegment?:return
            val prefs=context.getSharedPreferences("focus_events",Context.MODE_PRIVATE)
            val entries=JSONArray(prefs.getString("events","[]"))
            for(i in 0 until entries.length()){
                val e=entries.getJSONObject(i)
                if(e.getString("id")==id && e.getLong("at")<=System.currentTimeMillis()){
                    if(e.optBoolean("focus")){
                        val store=DisciplineStore(context)
                        if(store.prefs.getString("focusId",null)==id)store.setFocus(null,0)
                        FocusAccessibilityService.instance?.configurationChanged()
                    }
                    FocusNotifications.show(context,id.hashCode(),e.getString("title"),e.getString("body"))
                }
            }
        }catch(_:Exception){}
    }
}
