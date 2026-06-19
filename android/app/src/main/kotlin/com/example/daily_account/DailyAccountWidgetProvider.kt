package com.example.daily_account

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DailyAccountWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.daily_account_widget)

            // ── Launch intent (needed for click handlers throughout) ──
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)

            // ── Completion & streak ──
            val completion = widgetData.getString("completion", "0") ?: "0"
            val streakText = widgetData.getString("streak", "0 days") ?: "0 days"
            val doneCount = widgetData.getString("done_count", "0") ?: "0"

            views.setTextViewText(R.id.widget_completion, "${completion}%")
            views.setTextViewText(R.id.widget_streak, "\uD83D\uDD25 $streakText streak")
            views.setTextViewText(R.id.widget_done_count, "$doneCount/11 disciplines")

            // Color the completion percentage based on value
            val pct = completion.toIntOrNull() ?: 0
            val completionColor = when {
                pct >= 80 -> 0xFF6FBF73.toInt()  // green
                pct >= 50 -> 0xFFD4AF64.toInt()  // gold
                pct > 0   -> 0xFFE8D4A0.toInt()  // soft gold
                else      -> 0xFF7A6A4A.toInt()  // muted
            }
            views.setTextColor(R.id.widget_completion, completionColor)

            // ── Discipline icon grid ──
            val disciplines = listOf(
                Triple(R.id.widget_ic_bible, "d_bible", "\uD83D\uDCD6"),
                Triple(R.id.widget_ic_lit, "d_lit", "\uD83D\uDCDA"),
                Triple(R.id.widget_ic_ddeg, "d_ddeg", "\uD83D\uDD25"),
                Triple(R.id.widget_ic_prayer, "d_prayer", "\uD83D\uDE4F"),
                Triple(R.id.widget_ic_evangelism, "d_evangelism", "\uD83D\uDCE2"),
                Triple(R.id.widget_ic_fasting, "d_fasting", "\uD83C\uDF7D\uFE0F"),
                Triple(R.id.widget_ic_giving, "d_giving", "\uD83D\uDCB0"),
                Triple(R.id.widget_ic_church, "d_church", "\u26EA"),
                Triple(R.id.widget_ic_disciple, "d_disciple", "\uD83D\uDC65"),
                Triple(R.id.widget_ic_proclamation, "d_proclamation", "\uD83D\uDCE3"),
            )

            val discKeys = listOf(
                "bible", "literature", "ddeg", "prayerAlone", "evangelism",
                "fasting", "giving", "church", "discipleship", "proclamation"
            )

            for ((idx, triple) in disciplines.withIndex()) {
                val (viewId, key, emoji) = triple
                val done = widgetData.getString(key, "0") == "1"
                views.setTextViewText(viewId, if (done) "✓" else emoji)
                views.setInt(
                    viewId, "setBackgroundResource",
                    if (done) R.drawable.widget_disc_done else R.drawable.widget_disc_undone
                )
                views.setTextColor(
                    viewId,
                    if (done) 0xFFD4AF64.toInt() else 0xFF7A6A4A.toInt()
                )
                if (done) {
                    views.setFloat(viewId, "setTextSize", 16f)
                } else {
                    views.setFloat(viewId, "setTextSize", 14f)
                }

                // Quick-toggle: tap a discipline icon to toggle it
                val toggleIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    putExtra("open_tab", 1)
                    data = Uri.parse("dailyaccount://toggle/${discKeys[idx]}")
                }
                val togglePending = PendingIntent.getActivity(
                    context, 10 + idx, toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, togglePending)
            }

            // ── Active timer ──
            val timerActive = widgetData.getString("timer_active", "0") == "1"
            val timerLabel = widgetData.getString("timer_label", "") ?: ""
            val timerElapsed = widgetData.getString("timer_elapsed", "") ?: ""

            views.setViewVisibility(
                R.id.widget_timer_row,
                if (timerActive) View.VISIBLE else View.GONE
            )
            if (timerActive) {
                views.setTextViewText(R.id.widget_timer_label, timerLabel)
                views.setTextViewText(R.id.widget_timer_elapsed, timerElapsed)
            }

            // ── Scripture ──
            val scripture = widgetData.getString("scripture", "") ?: ""
            if (scripture.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_scripture_row, View.VISIBLE)
                views.setTextViewText(R.id.widget_scripture, scripture)
            } else {
                views.setViewVisibility(R.id.widget_scripture_row, View.GONE)
            }

            // ── Click intents ──
            // Tap widget body → open app
            val mainPending = PendingIntent.getActivity(
                context, 0,
                launchIntent ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_container, mainPending)

            // Log button → open app to log tab
            val logIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                putExtra("open_tab", 1) // Log tab
                data = Uri.parse("dailyaccount://log")
            }
            val logPending = PendingIntent.getActivity(
                context, 1, logIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_log, logPending)

            // Timer button → open app to stopwatch tab
            val timerIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                putExtra("open_tab", 0) // Stopwatch tab
                data = Uri.parse("dailyaccount://timer")
            }
            val timerPending = PendingIntent.getActivity(
                context, 2, timerIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_btn_timer, timerPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
