package com.jilengineering.dailyaccount

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DisciplineBarWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetHelper.ACTION_WIDGET_ACTION) {
            val actionType = intent.getStringExtra(WidgetHelper.EXTRA_ACTION_TYPE) ?: ""
            val actionData = intent.getStringExtra(WidgetHelper.EXTRA_ACTION_DATA) ?: ""
            if (actionType == "toggle" && actionData.isNotEmpty()) {
                toggleDiscipline(context, actionData)
                return
            }
        }
        super.onReceive(context, intent)
    }

    /**
     * Toggle a discipline directly in SharedPreferences and refresh the widget.
     * No app launch needed.
     */
    private fun toggleDiscipline(context: Context, disciplineKey: String) {
        val prefs = WidgetHelper.getWidgetPrefs(context)
        // Map toggle keys to prefs keys
        val prefsKey = when (disciplineKey) {
            "bible" -> "d_bible"
            "literature" -> "d_lit"
            "ddeg" -> "d_ddeg"
            "prayerAlone" -> "d_prayer"
            "evangelism" -> "d_evangelism"
            else -> return
        }
        val current = prefs.getString(prefsKey, "0") ?: "0"
        val newValue = if (current == "1") "0" else "1"
        prefs.edit().putString(prefsKey, newValue).apply()

        // Update completion percentage
        recalculateCompletion(prefs)

        // Refresh this widget and the full altar widget
        WidgetHelper.updateAllWidgets(context, DisciplineBarWidgetProvider::class.java)
        WidgetHelper.updateAllWidgets(context, FullAltarWidgetProvider::class.java)
    }

    /**
     * Recalculate completion % from discipline states.
     */
    private fun recalculateCompletion(prefs: SharedPreferences) {
        var done = 0
        for (key in WidgetHelper.DISC_KEYS_PREFS) {
            if (prefs.getString(key, "0") == "1") done++
        }
        val pct = (done * 100) / WidgetHelper.DISC_KEYS_PREFS.size
        prefs.edit().putString("completion", "$pct").apply()
    }

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
        val emojis = listOf("\uD83D\uDCD6", "\uD83D\uDCDA", "\uD83D\uDD25", "\uD83D\uDE4F", "\uD83D\uDCE2")

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_discipline_bar)

                // Completion ring
                val pct = WidgetHelper.getCompletion(widgetData)
                views.setTextViewText(R.id.disc_bar_completion, "$pct%")
                views.setTextColor(R.id.disc_bar_completion, WidgetHelper.completionColor(pct))

                // Streak
                val streak = WidgetHelper.getStreak(widgetData)
                views.setTextViewText(R.id.disc_bar_streak, "\uD83D\uDD25 $streak")

                // Discipline icons — broadcast toggle (no app launch)
                for (i in iconIds.indices) {
                    val viewId = iconIds[i]
                    val done = widgetData.getString(WidgetHelper.DISC_KEYS_PREFS[i], "0") == "1"

                    views.setTextViewText(viewId, if (done) "\u2713" else emojis[i])
                    views.setInt(
                        viewId, "setBackgroundResource",
                        if (done) R.drawable.widget_disc_pill_done else R.drawable.widget_disc_pill_undone
                    )
                    views.setTextColor(viewId, if (done) WidgetHelper.WHITE else WidgetHelper.CLAY)

                    // Quick-toggle via broadcast — does NOT open the app
                    val togglePending = WidgetHelper.widgetBroadcastIntent(
                        context,
                        DisciplineBarWidgetProvider::class.java,
                        200 + i,
                        "toggle",
                        WidgetHelper.DISC_KEYS_TOGGLE[i]
                    )
                    views.setOnClickPendingIntent(viewId, togglePending)
                }

                // Ring click -> open app
                val openPending = WidgetHelper.widgetPendingIntent(context, 210, "dailyaccount://open/log")
                views.setOnClickPendingIntent(R.id.disc_bar_ring_area, openPending)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.widget_discipline_bar)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
