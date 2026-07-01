package com.jilengineering.dailyaccount

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ProclamationWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == WidgetHelper.ACTION_WIDGET_ACTION) {
            val actionType = intent.getStringExtra(WidgetHelper.EXTRA_ACTION_TYPE) ?: ""
            if (actionType == "increment") {
                incrementCount(context)
                return
            }
        }
        super.onReceive(context, intent)
    }

    /**
     * Increment the proclamation count directly in SharedPreferences and
     * refresh the widget — all without opening the app.
     */
    private fun incrementCount(context: Context) {
        val prefs = WidgetHelper.getWidgetPrefs(context)
        val current = prefs.getString("proclamation_count", "0")?.toIntOrNull() ?: 0
        val newCount = current + 1
        prefs.edit().putString("proclamation_count", "$newCount").apply()

        // Refresh all proclamation widgets
        WidgetHelper.updateAllWidgets(context, ProclamationWidgetProvider::class.java)
        // Also refresh Full Altar widgets (they may show proclamation data)
        WidgetHelper.updateAllWidgets(context, FullAltarWidgetProvider::class.java)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_proclamation)
                val locale = WidgetHelper.getLocale(widgetData)

                // Counter value
                val count = widgetData.getString("proclamation_count", "0") ?: "0"
                views.setTextViewText(R.id.proclamation_count, count)

                // Localized label
                views.setTextViewText(R.id.proclamation_label,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_proclamations_today).uppercase())

                // "+" button — broadcast increment (does NOT open the app)
                val incrementPending = WidgetHelper.widgetBroadcastIntent(
                    context,
                    ProclamationWidgetProvider::class.java,
                    400,
                    "increment"
                )
                views.setOnClickPendingIntent(R.id.proclamation_btn_plus, incrementPending)

                // Tap counter number -> open app to full proclamation screen
                val openPending = WidgetHelper.widgetPendingIntent(context, 401, "dailyaccount://open/proclamation")
                views.setOnClickPendingIntent(R.id.proclamation_count, openPending)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.widget_proclamation)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
