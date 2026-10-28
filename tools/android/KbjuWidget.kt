package com.kbju.kbju_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

/**
 * Виджет на главный экран: калории, белок, шаги и вода за сегодня.
 * Данные пишет приложение (канал kbju/widget), шаги — ещё и фоновый шагомер.
 */
class KbjuWidget : AppWidgetProvider() {
    companion object {
        private const val PREFS = "kbju_widget"

        fun save(c: Context, data: Map<String, Any?>) {
            val e = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            for ((k, v) in data) {
                when (v) {
                    is Int -> e.putLong(k, v.toLong())
                    is Long -> e.putLong(k, v)
                    is Double -> e.putLong(k, Math.round(v))
                    is String -> e.putString(k, v)
                }
            }
            e.apply()
        }

        fun updateAll(c: Context) {
            try {
                val mgr = AppWidgetManager.getInstance(c)
                val ids = mgr.getAppWidgetIds(ComponentName(c, KbjuWidget::class.java))
                if (ids.isNotEmpty()) for (id in ids) update(c, mgr, id)
            } catch (e: Exception) {
            }
        }

        private fun fmt(v: Long): String = NumberFormat.getIntegerInstance(Locale.forLanguageTag("ru")).format(v)

        private fun pct(v: Long, t: Long): Int = if (t <= 0) 0 else ((v * 100) / t).toInt().coerceIn(0, 100)

        fun update(c: Context, mgr: AppWidgetManager, id: Int) {
            val p = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val today = StepStore.today()
            val sameDay = p.getString("day", "") == today
            fun num(k: String) = if (sameDay) p.getLong(k, 0) else 0L
            fun tgt(k: String, d: Long) = p.getLong(k, d)
            fun s(k: String, d: String) = p.getString(k, d) ?: d

            val kcal = num("kcal")
            val kcalT = tgt("kcalT", 2000)
            val prot = num("protein")
            val protT = tgt("proteinT", 120)
            val water = num("water")
            val waterT = tgt("waterT", 2000)
            val steps = maxOf(num("steps"), StepStore.todaySteps(c))
            val stepsT = tgt("stepsT", 10000)

            val v = RemoteViews(c.packageName, R.layout.kbju_widget)
            v.setTextViewText(R.id.w_title, s("title", "КБЖУ Трекер"))
            v.setTextViewText(R.id.w_level, s("level", ""))
            v.setTextViewText(R.id.w_kcal_label, s("kcalL", "Калории"))
            v.setTextViewText(R.id.w_kcal_val, "${fmt(kcal)} / ${fmt(kcalT)}")
            v.setProgressBar(R.id.w_kcal_bar, 100, pct(kcal, kcalT), false)
            v.setTextViewText(R.id.w_prot_label, s("proteinL", "Белок"))
            v.setTextViewText(R.id.w_prot_val, "${fmt(prot)} / ${fmt(protT)} ${s("g", "г")}")
            v.setProgressBar(R.id.w_prot_bar, 100, pct(prot, protT), false)
            v.setTextViewText(R.id.w_steps_label, s("stepsL", "Шаги"))
            v.setTextViewText(R.id.w_steps_val, "${fmt(steps)} / ${fmt(stepsT)}")
            v.setProgressBar(R.id.w_steps_bar, 100, pct(steps, stepsT), false)
            v.setTextViewText(R.id.w_water_label, s("waterL", "Вода"))
            v.setTextViewText(R.id.w_water_val, "${fmt(water)} / ${fmt(waterT)} ${s("ml", "мл")}")
            v.setProgressBar(R.id.w_water_bar, 100, pct(water, waterT), false)

            val intent = Intent(c, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pi = PendingIntent.getActivity(c, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            v.setOnClickPendingIntent(R.id.w_root, pi)
            mgr.updateAppWidget(id, v)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) update(context, appWidgetManager, id)
    }
}
