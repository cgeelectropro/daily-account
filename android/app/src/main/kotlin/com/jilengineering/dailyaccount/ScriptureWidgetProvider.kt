package com.jilengineering.dailyaccount

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ScriptureWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_scripture_card)
                val locale = WidgetHelper.getLocale(widgetData)

                // Get time-aware scripture content
                val (text, ref, label) = WidgetHelper.getScripture(context, widgetData, locale)

                views.setTextViewText(R.id.scripture_text, text)
                views.setTextViewText(R.id.scripture_label, label.uppercase())

                if (ref.isNotEmpty()) {
                    views.setTextViewText(R.id.scripture_ref, "\u2014 $ref")
                    views.setViewVisibility(R.id.scripture_ref, android.view.View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.scripture_ref, android.view.View.GONE)
                }

                // Tap -> open app to log
                val pendingIntent = WidgetHelper.widgetPendingIntent(context, 100, "dailyaccount://open/log")
                views.setOnClickPendingIntent(R.id.scripture_container, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                // Fallback: show initial layout so widget doesn't show "Error loading"
                val fallback = RemoteViews(context.packageName, R.layout.widget_scripture_card)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
