package com.personal.focus

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import java.time.Instant
import java.time.ZoneId

object NightScheduler {
    private fun pending(context:Context)=PendingIntent.getBroadcast(context,1,
        Intent(context,NightReceiver::class.java).setAction("com.personal.focus.BOUNDARY"),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    fun schedule(context:Context) {
        val store=NightStore(context); val manager=context.getSystemService(AlarmManager::class.java)
        manager.cancel(pending(context))
        if(!store.policy().enabled)return
        var next=store.policy().nextBoundary(Instant.now(),ZoneId.systemDefault(),store.prefs.getBoolean("warnings",true)).toEpochMilli()
        val expiry=store.overrideExpiry()
        if(expiry>0)next=minOf(next,System.currentTimeMillis()+expiry-SystemClock.elapsedRealtime())
        try {
            if(Build.VERSION.SDK_INT<31 || manager.canScheduleExactAlarms()) manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next,pending(context))
            else manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next,pending(context))
        } catch(_:SecurityException) { manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,next,pending(context)) }
    }
    fun warning(context:Context) {
        val store=NightStore(context)
        if(!store.policy().enabled || !store.prefs.getBoolean("warnings",true))return
        if(store.state()!=NightPolicy.State.PRE_LOCK_WARNING)return
        val next=store.policy().nextStart(Instant.now(),ZoneId.systemDefault())
        val minutes=((next.toEpochMilli()-System.currentTimeMillis()+59999)/60000).toInt()
        val bucket=when{minutes<=5->5;minutes<=10->10;else->20}
        val key="${next.toEpochMilli()}:$bucket"
        if(store.prefs.getString("lastWarning",null)==key)return
        if(Build.VERSION.SDK_INT>=33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)!=PackageManager.PERMISSION_GRANTED)return
        val manager=context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("night_warnings","Night Lock warnings",NotificationManager.IMPORTANCE_DEFAULT))
        val open=PendingIntent.getActivity(context,2,Intent(context,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        manager.notify(10,Notification.Builder(context,"night_warnings").setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Night Lock in $minutes minutes").setContentText("Finish what you're doing. Make room for rest.")
            .setContentIntent(open).setAutoCancel(true).build())
        store.prefs.edit().putString("lastWarning",key).apply()
    }
}
class NightReceiver:BroadcastReceiver() {
    override fun onReceive(context:Context,intent:Intent) {
        try {
            if(intent.action==Intent.ACTION_BOOT_COMPLETED)NightStore(context).endOverride("rebooted")
            NightScheduler.warning(context)
            NightScheduler.schedule(context)
            FocusEventScheduler.schedule(context)
            FocusAccessibilityService.instance?.configurationChanged()
        }catch(_:Exception){ /* Cannot prevent emergency use if native storage fails. */ }
    }
}
