package com.kbju.kbju_tracker

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Хранит шаги по дням. Датчик TYPE_STEP_COUNTER отдаёт шаги с момента включения телефона,
 * поэтому считаем разницу между показаниями и прибавляем её к текущему дню.
 */
object StepStore {
    private const val PREFS = "kbju_steps"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isEnabled(c: Context) = prefs(c).getBoolean("enabled", false)

    fun setEnabled(c: Context, v: Boolean) {
        prefs(c).edit().putBoolean("enabled", v).apply()
    }

    fun daysJson(c: Context): String = prefs(c).getString("days", "{}") ?: "{}"

    fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

    fun todaySteps(c: Context): Long =
        try { JSONObject(daysJson(c)).optLong(today(), 0) } catch (e: Exception) { 0 }

    /** Новое показание датчика. Возвращает шаги за сегодня. */
    @Synchronized
    fun onReading(c: Context, value: Long): Long {
        val p = prefs(c)
        val days = try { JSONObject(p.getString("days", "{}") ?: "{}") } catch (e: Exception) { JSONObject() }
        val day = today()
        val last = p.getLong("last", -1L)
        if (last >= 0) {
            var delta = value - last
            if (delta < 0) delta = value // телефон перезагружали — счётчик начался с нуля
            if (delta in 1..99999) days.put(day, days.optLong(day, 0) + delta)
        }
        if (days.length() > 400) {
            val keys = days.keys().asSequence().toList().sorted()
            keys.take(days.length() - 400).forEach { days.remove(it) }
        }
        p.edit().putLong("last", value).putString("days", days.toString()).apply()
        return days.optLong(day, 0)
    }
}

/** Фоновая служба: слушает датчик шагов, пока включена, даже если приложение закрыто. */
class StepService : Service(), SensorEventListener {
    companion object {
        private const val CHANNEL = "steps_counter"
        private const val NOTIF_ID = 4201

        fun hasSensor(c: Context): Boolean {
            val sm = c.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            return sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null
        }

        fun start(c: Context) {
            try {
                c.startForegroundService(Intent(c, StepService::class.java))
            } catch (e: Exception) {
                // Android может запретить запуск из фона — запустится при следующем открытии приложения.
            }
        }

        fun stop(c: Context) {
            c.stopService(Intent(c, StepService::class.java))
        }
    }

    private var sensorManager: SensorManager? = null
    private var lastShown = -1L
    private var lastShownAt = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        try {
            val n = buildNotification(StepStore.todaySteps(this))
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH)
            } else {
                startForeground(NOTIF_ID, n)
            }
        } catch (e: Exception) {
            stopSelf()
            return
        }
        val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sensorManager = sm
        val sensor = sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensor == null) {
            stopSelf()
            return
        }
        // Показания приходят пачками раз в ~30 секунд — так экономится батарея.
        sm.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL, 30_000_000)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        sensorManager?.unregisterListener(this)
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val steps = StepStore.onReading(this, event.values[0].toLong())
        val now = System.currentTimeMillis()
        if (steps != lastShown && now - lastShownAt > 10_000) {
            lastShown = steps
            lastShownAt = now
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIF_ID, buildNotification(steps))
            KbjuWidget.updateAll(this)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun createChannel() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val ch = NotificationChannel(CHANNEL, "Шагомер", NotificationManager.IMPORTANCE_LOW)
        ch.setShowBadge(false)
        ch.description = "Показывает шаги за сегодня, пока работает подсчёт"
        nm.createNotificationChannel(ch)
    }

    private fun buildNotification(steps: Long): Notification {
        val open = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pi = PendingIntent.getActivity(
            this, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val text = String.format(Locale.forLanguageTag("ru"), "%,d", steps)
        return Notification.Builder(this, CHANNEL)
            .setContentTitle("Шаги сегодня: $text")
            .setContentText("Шагомер считает в фоне")
            .setSmallIcon(R.drawable.ic_stat_steps)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setContentIntent(pi)
            .build()
    }
}

/** Запускает шагомер после перезагрузки телефона и после обновления приложения. */
class StepBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (StepStore.isEnabled(context)) StepService.start(context)
    }
}
