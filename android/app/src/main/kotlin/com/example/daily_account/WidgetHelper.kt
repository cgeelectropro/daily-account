// android/app/src/main/kotlin/com/example/daily_account/WidgetHelper.kt
package com.example.daily_account

import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
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
}
