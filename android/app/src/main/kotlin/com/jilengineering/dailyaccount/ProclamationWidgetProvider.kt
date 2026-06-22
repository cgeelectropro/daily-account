package com.jilengineering.dailyaccount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ProclamationWidgetProvider : HomeWidgetProvider() {

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

                // Localized text
                views.setTextViewText(R.id.proclamation_text,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_proclamation_text))
                views.setTextViewText(R.id.proclamation_label,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_proclamations_today).uppercase())

                val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)

                // Tap -> increment
                val incrementIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                    data = Uri.parse("dailyaccount://proclamation/increment")
                }
                val incrementPending = PendingIntent.getActivity(
                    context, 400, incrementIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.proclamation_container, incrementPending)

                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (e: Exception) {
                val fallback = RemoteViews(context.packageName, R.layout.widget_proclamation)
                appWidgetManager.updateAppWidget(widgetId, fallback)
            }
        }
    }
}
