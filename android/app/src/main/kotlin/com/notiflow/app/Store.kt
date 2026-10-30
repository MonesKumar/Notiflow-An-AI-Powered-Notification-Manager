package com.notiflow.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

class Store(context: Context) : SQLiteOpenHelper(context, "notiflow.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE notifications (id INTEGER PRIMARY KEY AUTOINCREMENT, pkg TEXT NOT NULL, app TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, time INTEGER NOT NULL, category TEXT NOT NULL, read_flag INTEGER NOT NULL DEFAULT 0, demo INTEGER NOT NULL DEFAULT 0)")
        db.execSQL("CREATE INDEX idx_notifications_time ON notifications(time DESC)")
        db.execSQL("CREATE TABLE preferences (pkg TEXT PRIMARY KEY, category TEXT NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    @Synchronized fun add(pkg: String, app: String, rawTitle: String, rawBody: String, time: Long, demo: Boolean = false) {
        val (title, body) = Classifier.sanitize(rawTitle, rawBody)
        val category = Classifier.classify(app, pkg, title, body, preference(pkg))
        writableDatabase.execSQL("INSERT INTO notifications(pkg,app,title,body,time,category,demo) VALUES(?,?,?,?,?,?,?)", arrayOf(pkg, app, title.ifBlank { "Notification" }, body, time, category, if (demo) 1 else 0))
        writableDatabase.execSQL("DELETE FROM notifications WHERE id NOT IN (SELECT id FROM notifications ORDER BY id DESC LIMIT 5000)")
    }
    @Synchronized fun preference(pkg: String): String? {
        readableDatabase.rawQuery("SELECT category FROM preferences WHERE pkg=?", arrayOf(pkg)).use { c -> return if (c.moveToFirst()) c.getString(0) else null }
    }
    @Synchronized fun list(): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        readableDatabase.rawQuery("SELECT id,pkg,app,title,body,time,category,read_flag,demo FROM notifications ORDER BY time DESC,id DESC LIMIT 5000", null).use { c ->
            while (c.moveToNext()) out.add(mapOf("id" to c.getLong(0), "pkg" to c.getString(1), "app" to c.getString(2), "title" to c.getString(3), "body" to c.getString(4), "time" to c.getLong(5), "category" to c.getString(6), "read" to (c.getInt(7) != 0), "demo" to (c.getInt(8) != 0)))
        }
        return out
    }
    @Synchronized fun preferences(): List<Map<String, String>> {
        val out = mutableListOf<Map<String, String>>()
        readableDatabase.rawQuery("SELECT pkg,category FROM preferences ORDER BY pkg", null).use { c ->
            while (c.moveToNext()) out.add(mapOf("pkg" to c.getString(0), "category" to c.getString(1)))
        }
        return out
    }
    @Synchronized fun correct(id: Long, category: String) {
        require(category in Classifier.categories)
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.rawQuery("SELECT pkg FROM notifications WHERE id=?", arrayOf(id.toString())).use { c ->
                if (c.moveToFirst()) {
                    val pkg = c.getString(0)
                    db.execSQL("UPDATE notifications SET category=? WHERE id=?", arrayOf(category, id))
                    db.execSQL("INSERT OR REPLACE INTO preferences(pkg,category) VALUES(?,?)", arrayOf(pkg, category))
                }
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    @Synchronized fun markRead(id: Long) { writableDatabase.execSQL("UPDATE notifications SET read_flag=1 WHERE id=?", arrayOf(id)) }
    @Synchronized fun delete(id: Long) { writableDatabase.execSQL("DELETE FROM notifications WHERE id=?", arrayOf(id)) }
    @Synchronized fun clear() { writableDatabase.execSQL("DELETE FROM notifications") }
    @Synchronized fun clearDemo() { writableDatabase.execSQL("DELETE FROM notifications WHERE demo=1") }
    @Synchronized fun removePreference(pkg: String) { writableDatabase.execSQL("DELETE FROM preferences WHERE pkg=?", arrayOf(pkg)) }
    @Synchronized fun clearPreferences() { writableDatabase.execSQL("DELETE FROM preferences") }
    @Synchronized fun seed() {
        clearDemo()
        val now = System.currentTimeMillis()
        val samples = listOf(
            arrayOf("demo.college", "College Portal", "Class announcement", "AI lab assignment deadline is Monday"),
            arrayOf("demo.exam", "Exam Cell", "Semester exam update", "Hall ticket available for tomorrow's exam"),
            arrayOf("demo.social", "Chat", "Aarav sent you a message", "Are you coming to the study group?"),
            arrayOf("demo.shop", "Shop", "Weekend sale", "Save 30% with a limited time offer"),
            arrayOf("demo.bank", "Bank", "Payment alert", "Your electricity payment was completed"),
            arrayOf("demo.security", "Device Security", "Security alert", "Suspicious sign-in on your account"),
            arrayOf("demo.everyday", "Weather", "Morning forecast", "Cloudy skies expected this afternoon")
        )
        samples.forEachIndexed { index, v -> add(v[0], v[1], v[2], v[3], now - index * 60000L, true) }
    }
}
