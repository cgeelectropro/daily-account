// android/app/src/main/kotlin/com/example/daily_account/FullAltarWidgetProvider.kt
package com.jilengineering.dailyaccount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class FullAltarWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val iconIds = listOf(
            R.id.altar_ic_bible,
            R.id.altar_ic_lit,
            R.id.altar_ic_ddeg,
            R.id.altar_ic_prayer,
            R.id.altar_ic_evangelism
        )
        val emojis = listOf("📖", "📚", "🔥", "🙏", "📢")

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_full_altar)
            val locale = WidgetHelper.getLocale(widgetData)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)

            // ── TOP ZONE: Scripture ──
            val (scriptureText, scriptureRef, scriptureLabel) =
                WidgetHelper.getScripture(context, widgetData, locale)
            views.setTextViewText(R.id.altar_scripture_text, scriptureText)
            if (scriptureRef.isNotEmpty()) {
                views.setTextViewText(R.id.altar_scripture_ref, scriptureRef)
                views.setViewVisibility(R.id.altar_scripture_ref, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.altar_scripture_ref, View.GONE)
            }

            // ── MIDDLE ZONE: Disciplines ──
            val pct = WidgetHelper.getCompletion(widgetData)
            views.setTextViewText(R.id.altar_completion, "$pct%")
            views.setTextColor(R.id.altar_completion, WidgetHelper.completionColor(pct))

            val streak = WidgetHelper.getStreak(widgetData)
            views.setTextViewText(R.id.altar_streak, "🔥 $streak")

            for (i in iconIds.indices) {
                val viewId = iconIds[i]
                val done = widgetData.getString(WidgetHelper.DISC_KEYS_PREFS[i], "0") == "1"

                views.setTextViewText(viewId, if (done) "✓" else emojis[i])
                views.setInt(
                    viewId, "setBackgroundResource",
                    if (done) R.drawable.widget_disc_pill_done else R.drawable.widget_disc_pill_undone
                )
                views.setTextColor(viewId, if (done) WidgetHelper.WHITE else WidgetHelper.CLAY)

                // Quick-toggle
                val toggleIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://toggle/${WidgetHelper.DISC_KEYS_TOGGLE[i]}")
                }
                val togglePending = PendingIntent.getActivity(
                    context, 300 + i, toggleIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(viewId, togglePending)
            }

            // Ring → open app
            val openLogIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                data = Uri.parse("dailyaccount://open/log")
            }
            val openLogPending = PendingIntent.getActivity(
                context, 310, openLogIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.altar_ring_area, openLogPending)

            // ── BOTTOM ZONE: Timer (adaptive) ──
            val timerRunning = widgetData.getString("timer_active", "0") == "1"
            val timerPaused = widgetData.getString("timer_paused", "0") == "1"
            val showPicker = widgetData.getString("show_timer_picker", "0") == "1"

            if (timerRunning || timerPaused) {
                // Timer is active — show running state
                views.setViewVisibility(R.id.altar_timer_idle, View.GONE)
                views.setViewVisibility(R.id.altar_timer_picker, View.GONE)
                views.setViewVisibility(R.id.altar_timer_running, View.VISIBLE)

                val timerLabel = widgetData.getString("timer_label", "") ?: ""
                views.setTextViewText(R.id.altar_timer_label, timerLabel)

                // Set chronometer base
                val elapsedMs = widgetData.getString("timer_elapsed_ms", "0")?.toLongOrNull() ?: 0L
                if (timerRunning) {
                    // Chronometer counts UP from base.
                    // base = elapsedRealtime() - totalElapsedMs so chronometer shows the right time.
                    val base = SystemClock.elapsedRealtime() - elapsedMs
                    views.setChronometer(R.id.altar_chronometer, base, null, true)
                    views.setTextColor(R.id.altar_timer_dot, WidgetHelper.GREEN)
                } else {
                    // Paused — show frozen time
                    val base = SystemClock.elapsedRealtime() - elapsedMs
                    views.setChronometer(R.id.altar_chronometer, base, null, false)
                    views.setTextColor(R.id.altar_timer_dot, WidgetHelper.CLAY)
                }

                // Pause/Resume button
                val pauseIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://timer/pause")
                }
                val pausePending = PendingIntent.getActivity(
                    context, 320, pauseIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.altar_btn_pause, pausePending)
                views.setTextViewText(R.id.altar_btn_pause, if (timerPaused) "▶" else "⏸")

                // Stop button
                val stopIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://timer/stop")
                }
                val stopPending = PendingIntent.getActivity(
                    context, 321, stopIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.altar_btn_stop, stopPending)

            } else if (showPicker) {
                // Show discipline picker
                views.setViewVisibility(R.id.altar_timer_idle, View.GONE)
                views.setViewVisibility(R.id.altar_timer_picker, View.VISIBLE)
                views.setViewVisibility(R.id.altar_timer_running, View.GONE)

                // Localized picker labels
                views.setTextViewText(
                    R.id.altar_pick_prayer,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_prayer)
                )
                views.setTextViewText(
                    R.id.altar_pick_bible,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_bible)
                )
                views.setTextViewText(
                    R.id.altar_pick_literature,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_literature)
                )

                // Picker click handlers
                val timerDisciplines = listOf("prayerAlone", "bible", "literature")
                val pickerIds = listOf(
                    R.id.altar_pick_prayer,
                    R.id.altar_pick_bible,
                    R.id.altar_pick_literature
                )
                for (i in pickerIds.indices) {
                    val startIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                        data = Uri.parse("dailyaccount://timer/start/${timerDisciplines[i]}")
                    }
                    val startPending = PendingIntent.getActivity(
                        context, 330 + i, startIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(pickerIds[i], startPending)
                }

            } else {
                // Idle — show buttons + motivational text
                views.setViewVisibility(R.id.altar_timer_idle, View.VISIBLE)
                views.setViewVisibility(R.id.altar_timer_picker, View.GONE)
                views.setViewVisibility(R.id.altar_timer_running, View.GONE)

                // Motivational text
                val daysThisWeek = widgetData.getString("days_this_week", "0")?.toIntOrNull() ?: 0
                val motivational = if (daysThisWeek > 0) {
                    WidgetHelper.getLocalizedString(
                        context, locale, R.string.widget_days_this_week, daysThisWeek
                    )
                } else {
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_keep_streak)
                }
                views.setTextViewText(R.id.altar_motivational, motivational)

                // Button labels
                views.setTextViewText(
                    R.id.altar_btn_start_timer,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_start_timer)
                )
                views.setTextViewText(
                    R.id.altar_btn_open_log,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_open_log)
                )

                // Start Timer → show picker (deep link handled by app)
                val pickerIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://timer/picker")
                }
                val pickerPending = PendingIntent.getActivity(
                    context, 340, pickerIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.altar_btn_start_timer, pickerPending)

                // Open Log button
                views.setOnClickPendingIntent(R.id.altar_btn_open_log, openLogPending)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
