package com.personal.focus

import android.app.*
import android.content.Context
import android.content.Intent

object FocusNotifications {
    fun show(context:Context,id:Int,title:String,body:String){
        try {
            val manager=context.getSystemService(NotificationManager::class.java)
            if(!manager.areNotificationsEnabled())return
            manager.createNotificationChannel(NotificationChannel("focus_events","Focus and limits",NotificationManager.IMPORTANCE_DEFAULT))
            val open=PendingIntent.getActivity(context,id,Intent(context,MainActivity::class.java),PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            manager.notify(id,Notification.Builder(context,"focus_events").setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title).setContentText(body).setVisibility(Notification.VISIBILITY_PRIVATE).setContentIntent(open).setAutoCancel(true).build())
        }catch(_:SecurityException){}
    }
}
