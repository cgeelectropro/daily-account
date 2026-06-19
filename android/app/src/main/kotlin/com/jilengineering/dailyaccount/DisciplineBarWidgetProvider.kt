// android/app/src/main/kotlin/com/example/daily_account/DisciplineBarWidgetProvider.kt
package com.jilengineering.dailyaccount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DisciplineBarWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val iconIds = listOf(
            R.id.disc_bar_ic_bible,
            R.id.disc_bar_ic_lit,
            R.id.disc_bar_ic_ddeg,
            R.id.disc_bar_ic_prayer,
            R.id.disc_bar_ic_evangelism
        )
        val emojis = listOf("📖", "📚", "🔥", "🙏", "📢")

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_discipline_bar)

            // ── Completion ring ──
            val pct = WidgetHelper.getCompletion(widgetData)
            views.setTextViewText(R.id.disc_bar_completion, "$pct%")
            views.setTextColor(R.id.disc_bar_completion, WidgetHelper.completionColor(pct))

            // ── Streak ──
            val streak = WidgetHelper.getStreak(widgetData)
            views.setTextViewText(R.id.disc_bar_streak, "🔥 $streak")

            // ── Discipline icons ──
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)

            for (i in iconIds.indices) {
                val viewId = iconIds[i]
                val done = widgetData.getString(WidgetHelper.DISC_KEYS_PREFS[i], "0") == "1"

                views.setTextViewText(viewId, if (done) "✓" else emojis[i])
                views.setInt(
                    viewId, "setBackgroundResource",
                    if (done) R.drawable.widget_disc_pill_done else R.drawable.widget_disc_pill_undone
                )
                views.setTextColor(viewId, if (done) WidgetHelper.WHITE else WidgetHelper.CLAY)
                views.setFloat(viewId, "setTextSize", if (done) 16f else 16f)

                // Quick-toggle click handler
                val toggleIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://toggle/${WidgetHelper.DISC_KEYS_TOGGLE[i]}")
                }
                val togglePending = PendingIntent.getActivity(
                    context, 200 + i, toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, togglePending)
            }

            // ── Ring click → open app ──
            val openIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                data = Uri.parse("dailyaccount://open/log")
            }
            val openPending = PendingIntent.getActivity(
                context, 210, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.disc_bar_ring_area, openPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
