package com.personal.focus

import android.content.Context
import android.os.SystemClock
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.ZoneId

class NightStore(val context: Context) {
    val prefs = context.getSharedPreferences("focus_night_v1", Context.MODE_PRIVATE)
    fun policy(): NightPolicy = try {
        NightPolicy(prefs.getInt("startMinute",1260),prefs.getInt("endMinute",420),prefs.getBoolean("enabled",false))
    } catch (_: RuntimeException) { NightPolicy(1260,420,false) } // corrupt config fails open
    fun configure(values: Map<*,*>) {
        val start=(values["startMinute"] as? Number)?.toInt() ?: policy().startMinute
        val end=(values["endMinute"] as? Number)?.toInt() ?: policy().endMinute
        NightPolicy(start,end,true) // validate before any write
        val edit=prefs.edit().putInt("startMinute",start).putInt("endMinute",end)
        (values["enabled"] as? Boolean)?.let { edit.putBoolean("enabled",it) }
        (values["warnings"] as? Boolean)?.let { edit.putBoolean("warnings",it) }
        (values["overrideMinutes"] as? Number)?.toInt()?.let {
            require(it in listOf(5,15,30)); edit.putInt("overrideMinutes",it)
        }
        (values["whitelist"] as? List<*>)?.let { list ->
            val packages=list.map { it as String }.filter { it.matches(Regex("[A-Za-z0-9_.]+")) }.toSet()
            require(packages.size<=300); edit.putStringSet("whitelist",packages)
        }
        check(edit.commit()) { "Settings unavailable" }
        if (values.containsKey("startMinute") || values.containsKey("endMinute") || values["enabled"]==false) endOverride("configuration_changed")
    }
    fun whitelist(): Set<String> = prefs.getStringSet("whitelist",emptySet())?.toSet() ?: emptySet()
    fun overrides(): JSONArray = try { JSONArray(prefs.getString("overrides","[]")) } catch (_: Exception) { JSONArray() }
    fun overrideExpiry(): Long {
        val expiry=prefs.getLong("overrideExpiry",0)
        if (expiry<=0) return 0
        val now=SystemClock.elapsedRealtime()
        val boot=prefs.getInt("overrideBoot",-1)
        val currentBoot=android.provider.Settings.Global.getInt(context.contentResolver,"boot_count",-2)
        if (boot!=currentBoot || now<prefs.getLong("overrideStartedElapsed",0)) {
            endOverride("rebooted"); return 0
        }
        if (now>=expiry) { endOverride("expired"); return 0 }
        if (prefs.getBoolean("overrideNight",false) && policy().intervalContaining(Instant.now(),ZoneId.systemDefault())==null) {
            endOverride("schedule_ended"); return 0
        }
        return expiry
    }
    fun state(): NightPolicy.State = policy().state(Instant.now(),ZoneId.systemDefault(),SystemClock.elapsedRealtime(),overrideExpiry())
    fun beginOverride(reason: String, emergency: Boolean = false) {
        require(reason in listOf("Emergency","Important communication","Work / Study","Travel","Other"))
        if (prefs.getLong("overrideExpiry",0)>0) endOverride("replaced")
        val minutes=if(emergency)15 else prefs.getInt("overrideMinutes",15)
        val elapsed=SystemClock.elapsedRealtime()
        val end=policy().intervalContaining(Instant.now(),ZoneId.systemDefault())?.get(1)
        val maxDuration=end?.let { (it.toEpochMilli()-System.currentTimeMillis()).coerceAtLeast(0) } ?: minutes*60000L
        val duration=(minutes*60000L).coerceAtMost(maxDuration)
        val history=overrides()
        history.put(JSONObject().put("startedAt",System.currentTimeMillis()).put("reason",reason)
            .put("durationMs",duration).put("status","active").put("emergency",emergency))
        val trimmed=JSONArray(); for(i in (history.length()-200).coerceAtLeast(0) until history.length()) trimmed.put(history.get(i))
        check(prefs.edit().putLong("overrideExpiry",elapsed+duration).putLong("overrideStartedElapsed",elapsed).putBoolean("overrideNight",end!=null)
            .putInt("overrideBoot",android.provider.Settings.Global.getInt(context.contentResolver,"boot_count",-1))
            .putString("overrides",trimmed.toString()).commit())
    }
    fun endOverride(reason:String) {
        val history=overrides()
        if(history.length()>0) {
            val last=history.getJSONObject(history.length()-1)
            if(last.optString("status")=="active") {
                val scheduledEnd=last.optLong("startedAt")+last.optLong("durationMs")
                last.put("status",reason).put("endedAt",if(reason=="expired")scheduledEnd else System.currentTimeMillis())
            }
        }
        prefs.edit().remove("overrideExpiry").remove("overrideStartedElapsed").putString("overrides",history.toString()).commit()
    }
}
