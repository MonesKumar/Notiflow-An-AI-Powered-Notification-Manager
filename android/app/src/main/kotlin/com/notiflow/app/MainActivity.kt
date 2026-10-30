package com.notiflow.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.notiflow.app/native"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            try {
                val store = Store(applicationContext)
                val id = (call.argument<Number>("id") ?: 0).toLong()
                when (call.method) {
                    "hasAccess" -> result.success(hasAccess())
                    "requestAccess" -> { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)); result.success(null) }
                    "list" -> result.success(store.list())
                    "preferences" -> result.success(store.preferences())
                    "correct" -> { store.correct(id, call.argument<String>("category") ?: ""); result.success(null) }
                    "markRead" -> { store.markRead(id); result.success(null) }
                    "delete" -> { store.delete(id); result.success(null) }
                    "clear" -> { store.clear(); result.success(null) }
                    "clearDemo" -> { store.clearDemo(); result.success(null) }
                    "seed" -> { store.seed(); result.success(null) }
                    "removePreference" -> { store.removePreference(call.argument<String>("pkg") ?: ""); result.success(null) }
                    "clearPreferences" -> { store.clearPreferences(); result.success(null) }
                    "openApp" -> {
                        val pkg = call.argument<String>("pkg") ?: ""
                        if (pkg.startsWith("demo.")) result.success(false)
                        else {
                            val launch = packageManager.getLaunchIntentForPackage(pkg)
                            if (launch == null) result.success(false)
                            else { startActivity(launch); result.success(true) }
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("NATIVE_ERROR", e.message ?: "Operation failed", null) }
        }
    }
    private fun hasAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= 27) {
            val manager = getSystemService(android.app.NotificationManager::class.java)
            return manager.isNotificationListenerAccessGranted(android.content.ComponentName(this, NotiflowListener::class.java))
        }
        val enabled = Settings.Secure.getString(contentResolver, "enabled_notification_listeners") ?: return false
        return enabled.split(':').any { component ->
            val c = android.content.ComponentName.unflattenFromString(component)
            c?.packageName == packageName && c.className == NotiflowListener::class.java.name
        }
    }
}
