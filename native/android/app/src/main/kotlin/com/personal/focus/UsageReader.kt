package com.personal.focus

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process

object UsageReader {
    fun allowed(context: Context): Boolean {
        val ops=context.getSystemService(AppOpsManager::class.java)
        val mode=if(Build.VERSION.SDK_INT>=29)ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),context.packageName)
            else ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,Process.myUid(),context.packageName)
        return mode==AppOpsManager.MODE_ALLOWED
    }
    fun totals(context:Context,start:Long,end:Long):Map<String,Long> {
        require(end>start)
        val events=context.getSystemService(UsageStatsManager::class.java).queryEvents((start-86400000L).coerceAtLeast(0),end)
            ?:return emptyMap()
        val accumulator=UsageAccumulator(start,end);val event=UsageEvents.Event()
        while(events.hasNextEvent()){events.getNextEvent(event);accumulator.event(event.timeStamp,event.packageName,event.eventType)}
        return accumulator.finish()
    }
}
