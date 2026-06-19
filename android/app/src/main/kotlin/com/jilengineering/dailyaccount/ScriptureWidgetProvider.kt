// android/app/src/main/kotlin/com/example/daily_account/ScriptureWidgetProvider.kt
package com.jilengineering.dailyaccount

import android.appwidget.AppWidgetManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
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

            // Tap → open app to log
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val openIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                data = Uri.parse("dailyaccount://open/log")
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 100, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.scripture_container, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
