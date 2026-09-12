package com.personal.focus

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

/** Coverage is evidence of service observation, never inferred from an enabled toggle.
 * Sleep/process gaps greater than 90 seconds remain unknown. */
class NightAudit(private val context:Context){
    private val prefs=context.getSharedPreferences("focus_observation",Context.MODE_PRIVATE)
    private var lastWall=0L
    private var lastElapsed=0L
    private var activeStart=0L
    private var activeEnd=0L
    fun rows():JSONArray=try{JSONArray(prefs.getString("nights","[]"))}catch(_:Exception){JSONArray()}
    fun observe(){
        val now=System.currentTimeMillis();val elapsed=SystemClock.elapsedRealtime();val rows=rows()
        if(activeStart>0){
            val row=(0 until rows.length()).map{rows.getJSONObject(it)}.firstOrNull{it.optLong("start")==activeStart}
            if(row!=null){
                val wall=now-lastWall;val mono=elapsed-lastElapsed
                if(lastWall>0&&wall in 0..90000L&&kotlin.math.abs(wall-mono)<3000){
                    val covered=(minOf(now,activeEnd)-maxOf(lastWall,activeStart)).coerceAtLeast(0)
                    row.put("observedMs",minOf(activeEnd-activeStart,row.optLong("observedMs")+covered))
                }
                row.put("lastObserved",now)
                if(now>=activeEnd)row.put("finished",true)
            }
        }
        val interval=NightStore(context).policy().intervalContaining(Instant.ofEpochMilli(now),ZoneId.systemDefault())
        val start=interval?.get(0)?.toEpochMilli()?:0L;val end=interval?.get(1)?.toEpochMilli()?:0L
        if(start!=0L && (0 until rows.length()).none{rows.getJSONObject(it).optLong("start")==start}){
            rows.put(JSONObject().put("start",start).put("end",end).put("observedMs",0).put("finished",false))
        }
        activeStart=start;activeEnd=end;lastWall=now;lastElapsed=elapsed
        val trimmed=JSONArray();for(i in (rows.length()-90).coerceAtLeast(0) until rows.length())trimmed.put(rows.get(i))
        prefs.edit().putString("nights",trimmed.toString()).apply()
    }
}
