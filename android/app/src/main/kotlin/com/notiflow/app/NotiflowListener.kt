package com.notiflow.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class NotiflowListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || sbn.packageName == packageName) return
        val notification = sbn.notification ?: return
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0 || notification.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        try {
            val extras = notification.extras
            val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
            val body = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
                ?: extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
            val app = try {
                val info = packageManager.getApplicationInfo(sbn.packageName, 0)
                packageManager.getApplicationLabel(info).toString()
            } catch (_: Exception) { sbn.packageName.substringAfterLast('.') }
            Store(applicationContext).add(sbn.packageName, app, title, body, sbn.postTime)
        } catch (_: Exception) { /* Restricted or malformed notification: never crash listener. */ }
    }
}
