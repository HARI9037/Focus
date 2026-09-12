package com.personal.focus

import android.content.Context
import org.json.JSONArray

class DisciplineStore(context:Context) {
    val prefs=context.getSharedPreferences("focus_discipline_v1",Context.MODE_PRIVATE)
    fun rules():List<DisciplinePolicy.Rule> = try {
        val array=JSONArray(prefs.getString("rules","[]"))
        (0 until array.length()).map { i ->
            val r=array.getJSONObject(i);val packages=r.getJSONArray("packages")
            DisciplinePolicy.Rule(r.getString("id"),r.getString("label"),
                (0 until packages.length()).map{packages.getString(it)}.toSet(),
                r.optLong("minutes")*60000L,r.optLong("blockedUntil"),r.optBoolean("duringFocus"))
        }
    }catch(_:Exception){emptyList()}
    fun configure(raw:String) {
        val array=JSONArray(raw);require(array.length()<=300)
        val ids=mutableSetOf<String>()
        for(i in 0 until array.length()){
            val r=array.getJSONObject(i);require(ids.add(r.getString("id")))
            require(r.getString("label").length in 1..120);require(r.getLong("minutes") in 0..1440)
            val packages=r.getJSONArray("packages");require(packages.length() in 1..300)
            for(j in 0 until packages.length())require(packages.getString(j).matches(Regex("[A-Za-z0-9_.]+")))
            require(r.optLong("blockedUntil")>=0)
        }
        check(prefs.edit().putString("rules",raw).commit())
    }
    fun setFocus(id:String?,end:Long) {
        check(prefs.edit().putString("focusId",id).putLong("focusEnd",end).commit())
    }
    fun focusing():Boolean = prefs.getString("focusId",null)!=null &&
        (prefs.getLong("focusEnd",0)==0L || prefs.getLong("focusEnd",0)>System.currentTimeMillis())
}
