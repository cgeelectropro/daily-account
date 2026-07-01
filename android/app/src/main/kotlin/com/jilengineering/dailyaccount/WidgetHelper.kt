// android/app/src/main/kotlin/com/jilengineering/dailyaccount/WidgetHelper.kt
package com.jilengineering.dailyaccount

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Build
import org.json.JSONArray
import java.util.Calendar
import java.util.Locale

object WidgetHelper {
    // ── Color constants (matching AppTheme) ──
    const val GOLD = 0xFFD4AF64.toInt()
    const val GOLD_DEEP = 0xFFA07830.toInt()
    const val GOLD_SOFT = 0xFFE8D4A0.toInt()
    const val SAND = 0xFFA09070.toInt()
    const val CLAY = 0xFF7A6A4A.toInt()
    const val GREEN = 0xFF6FBF73.toInt()
    const val RUST = 0xFFC97B5A.toInt()
    const val CREAM = 0xFFF0E8D8.toInt()
    const val ESPRESSO = 0xFF1A1208.toInt()
    const val DEEP_BG = 0xFF0D0A05.toInt()
    const val WHITE = 0xFFFFFFFF.toInt()

    // ── Discipline abbreviations (same in both languages for space) ──
    val DISC_LABELS = listOf("BIB", "LIT", "DDG", "PRY", "EVG")

    /**
     * Get the 3-letter abbreviation for a discipline by index.
     */
    fun getDisciplineLabel(index: Int): String {
        return if (index in DISC_LABELS.indices) DISC_LABELS[index] else ""
    }

    // ── Discipline SharedPreferences keys (5 core for new widgets) ──
    val DISC_KEYS_PREFS = listOf("d_bible", "d_lit", "d_ddeg", "d_prayer", "d_evangelism")
    val DISC_KEYS_TOGGLE = listOf("bible", "literature", "ddeg", "prayerAlone", "evangelism")

    /**
     * Read the app's chosen locale from widget SharedPreferences.
     * Falls back to "en" if not set.
     */
    fun getLocale(widgetData: SharedPreferences): String {
        return widgetData.getString("widget_locale", "en") ?: "en"
    }

    /**
     * Get a string resource using the specified locale, not the device locale.
     * This allows the widget to match the app's in-app language setting.
     */
    fun getLocalizedString(context: Context, locale: String, resId: Int): String {
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale(locale))
        val localizedContext = context.createConfigurationContext(config)
        return localizedContext.getString(resId)
    }

    /**
     * Get a formatted string resource using the specified locale.
     */
    fun getLocalizedString(context: Context, locale: String, resId: Int, vararg args: Any): String {
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale(locale))
        val localizedContext = context.createConfigurationContext(config)
        return localizedContext.getString(resId, *args)
    }

    /**
     * Returns (scriptureText, label) based on time of day and DDEG status.
     *
     * Logic:
     * - If DDEG was logged today (ddeg_scripture non-empty in widgetData) → user's own scripture + "Your Word Today"
     * - 6 AM – 12 PM → daily verse from verses.json + "Daily Verse"
     * - 12 PM – 10 PM → fixed proclamation + "Proclamation"
     * - 10 PM – 6 AM → daily verse (nighttime devotion)
     */
    fun getScripture(context: Context, widgetData: SharedPreferences, locale: String): Triple<String, String, String> {
        // Check if DDEG was logged today
        val ddegScripture = widgetData.getString("ddeg_scripture", "") ?: ""
        if (ddegScripture.isNotEmpty()) {
            val label = getLocalizedString(context, locale, R.string.widget_your_word_today)
            return Triple(ddegScripture, "", label)
        }

        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)

        // Afternoon/evening → proclamation
        if (hour in 12..21) {
            val text = getLocalizedString(context, locale, R.string.widget_proclamation_text)
            val label = getLocalizedString(context, locale, R.string.widget_proclamation_label)
            return Triple(text, "", label)
        }

        // Morning or late night → daily verse
        val dayOfYear = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
        val verse = loadVerse(context, dayOfYear, locale)
        val label = getLocalizedString(context, locale, R.string.widget_daily_verse)
        return Triple(verse.first, verse.second, label)
    }

    /**
     * Load a verse from assets/verses.json by day-of-year index.
     * Returns (text, reference).
     */
    private fun loadVerse(context: Context, dayOfYear: Int, locale: String): Pair<String, String> {
        return try {
            val json = context.assets.open("flutter_assets/assets/verses.json")
                .bufferedReader().use { it.readText() }
            val arr = JSONArray(json)
            val index = dayOfYear % arr.length()
            val obj = arr.getJSONObject(index)
            val text = obj.optString(locale, obj.optString("en", ""))
            val ref = obj.optString("ref", "")
            Pair(text, ref)
        } catch (e: Exception) {
            Pair("Be faithful unto death, and I will give you the crown of life.", "Rev 2:10")
        }
    }

    /**
     * Read completion percentage from widget data.
     */
    fun getCompletion(widgetData: SharedPreferences): Int {
        val raw = widgetData.getString("completion", "0") ?: "0"
        return raw.toIntOrNull() ?: 0
    }

    /**
     * Read streak text from widget data.
     */
    fun getStreak(widgetData: SharedPreferences): String {
        return widgetData.getString("streak", "0 days") ?: "0 days"
    }

    /**
     * Color for completion percentage text.
     */
    fun completionColor(pct: Int): Int = when {
        pct >= 80 -> GREEN
        pct >= 50 -> GOLD
        pct > 0   -> GOLD_SOFT
        else      -> CLAY
    }

    /**
     * Create a PendingIntent that routes through home_widget's click handler.
     * This ensures HomeWidget.widgetClicked stream receives the URI on the Flutter side.
     * NOTE: This launches the app — use [widgetBroadcastIntent] for in-widget actions.
     *
     * @param requestCode unique per-button code to avoid PendingIntent deduplication
     * @param uri the deep link URI (e.g. "dailyaccount://toggle/bible")
     */
    fun widgetPendingIntent(context: Context, requestCode: Int, uri: String): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = "es.antonborri.home_widget.action.LAUNCH"
            data = Uri.parse(uri)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    // ── Broadcast-based widget actions (no app launch) ──

    const val ACTION_WIDGET_ACTION = "com.jilengineering.dailyaccount.WIDGET_ACTION"
    const val EXTRA_ACTION_TYPE = "action_type"
    const val EXTRA_ACTION_DATA = "action_data"

    /**
     * Create a PendingIntent that sends a broadcast to a widget provider.
     * The widget handles the action in onReceive — the app does NOT open.
     *
     * @param receiverClass the widget provider class (e.g. ProclamationWidgetProvider::class.java)
     * @param requestCode unique code to avoid PendingIntent deduplication
     * @param actionType identifier like "increment" or "toggle"
     * @param actionData extra data like discipline key
     */
    fun widgetBroadcastIntent(
        context: Context,
        receiverClass: Class<*>,
        requestCode: Int,
        actionType: String,
        actionData: String = ""
    ): PendingIntent {
        val intent = Intent(context, receiverClass).apply {
            action = ACTION_WIDGET_ACTION
            putExtra(EXTRA_ACTION_TYPE, actionType)
            putExtra(EXTRA_ACTION_DATA, actionData)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(context, requestCode, intent, flags)
    }

    /**
     * Get the home_widget SharedPreferences (same store Flutter reads/writes).
     */
    fun getWidgetPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
    }

    /**
     * Force-update all instances of a widget provider class.
     */
    fun updateAllWidgets(context: Context, providerClass: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val component = android.content.ComponentName(context, providerClass)
        val ids = manager.getAppWidgetIds(component)
        if (ids.isNotEmpty()) {
            val intent = Intent(context, providerClass).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            }
            context.sendBroadcast(intent)
        }
    }
}
