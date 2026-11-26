package com.kbju.kbju_tracker

import android.app.Application
import android.content.Context
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Ловит падения на стороне Android — даже те, что случаются до запуска Flutter
 * (например, в библиотеке при старте, как в сборке 36). Ошибка дописывается в тот же файл,
 * что и ошибки Flutter (winter_core: winter_crash.log), и при следующем запуске
 * приложение покажет плашку «Сообщить».
 */
class WinterApp : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        val prev = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val sw = StringWriter()
                error.printStackTrace(PrintWriter(sw))
                val lines = sw.toString().lines().filter { it.isNotBlank() }.take(40).joinToString("\n")
                val time = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US).format(Date())
                val f = File(base.filesDir, "winter_crash.log")
                var old = if (f.exists()) f.readText() else ""
                if (old.length > 24 * 1024) old = old.substring(old.length - 12 * 1024)
                f.writeText("$old=== $time (Android, поток ${thread.name})\n$lines\n")
            } catch (_: Throwable) {
            }
            prev?.uncaughtException(thread, error)
        }
    }
}
