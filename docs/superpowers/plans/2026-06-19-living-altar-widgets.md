# Living Altar Widget System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic 4x3 Android widget with four purpose-built widgets (Scripture Card 2x2, Discipline Bar 4x2, Full Altar 4x3, Proclamation Counter 2x2) featuring real-time sync, timer controls, time-aware scripture, and bilingual support.

**Architecture:** Each widget has its own provider class, layout XML, and appwidget-info XML, sharing a `WidgetHelper.kt` utility for common operations (reading SharedPreferences, selecting locale strings, loading scripture). The Flutter side pushes all widget data via `HomeWidget.saveWidgetData()` on every state change. Deep link URIs enable widget-to-app communication for discipline toggling, timer control, and proclamation counting.

**Tech Stack:** Kotlin (Android widget providers), Android RemoteViews/XML layouts, `home_widget` Flutter plugin, SharedPreferences, `Chronometer` RemoteView for live timer, `AlarmManager` for scripture refresh.

## Global Constraints

- Min SDK: follows `flutter.minSdkVersion` (21+)
- Widget colors: espresso `#1A1208` bg, gold `#D4AF64` accent, sand `#A09070` muted, clay `#7A6A4A` faint, green `#6FBF73` active, deep bg `#0D0A05`
- Typography: serif font family in widget XML (closest to Cormorant Garamond/Lora available in RemoteViews)
- All widget text must respect the `widget_locale` SharedPreferences value (`"en"` or `"fr"`)
- The existing `DailyAccountWidgetProvider` and its layout are kept working during development — removal happens in the final task
- All data keys used by `HomeWidget.saveWidgetData()` are strings (the home_widget plugin stores everything as strings)
- The `home_widget` package name for `HomeWidget.updateWidget()` is `androidName: '<ProviderClassName>'`
- No test suite exists — testing is manual on device/emulator

---

### Task 1: Shared Drawables and String Resources

Create all shared drawable XMLs and bilingual string resources that the four widget layouts will reference.

**Files:**
- Create: `android/app/src/main/res/drawable/widget_altar_bg.xml`
- Create: `android/app/src/main/res/drawable/widget_altar_bg_darker.xml`
- Create: `android/app/src/main/res/drawable/widget_gold_border.xml`
- Create: `android/app/src/main/res/drawable/widget_gold_divider.xml`
- Create: `android/app/src/main/res/drawable/widget_disc_pill_done.xml`
- Create: `android/app/src/main/res/drawable/widget_disc_pill_undone.xml`
- Create: `android/app/src/main/res/drawable/widget_btn_gold_fill.xml`
- Create: `android/app/src/main/res/drawable/widget_btn_gold_outline.xml`
- Create: `android/app/src/main/res/drawable/widget_btn_stop.xml`
- Create: `android/app/src/main/res/drawable/widget_cross_watermark.xml`
- Modify: `android/app/src/main/res/values/strings.xml`
- Create: `android/app/src/main/res/values-fr/strings.xml`

**Interfaces:**
- Produces: drawable resources referenced by `@drawable/widget_altar_bg`, etc. in all layout XMLs
- Produces: string resources referenced by `@string/widget_*` in provider Kotlin code via `context.getString(R.string.widget_*)`

- [ ] **Step 1: Create widget_altar_bg.xml — primary espresso background with gold border**

```xml
<!-- android/app/src/main/res/drawable/widget_altar_bg.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#1A1208" />
    <corners android:radius="20dp" />
    <stroke android:width="1dp" android:color="#44D4AF64" />
</shape>
```

- [ ] **Step 2: Create widget_altar_bg_darker.xml — darker espresso for scripture strip**

```xml
<!-- android/app/src/main/res/drawable/widget_altar_bg_darker.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#120E06" />
    <corners android:topLeftRadius="20dp" android:topRightRadius="20dp" />
</shape>
```

- [ ] **Step 3: Create widget_gold_divider.xml — thin gold line separator**

```xml
<!-- android/app/src/main/res/drawable/widget_gold_divider.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#44D4AF64" />
    <size android:height="1dp" />
</shape>
```

- [ ] **Step 4: Create widget_disc_pill_done.xml and widget_disc_pill_undone.xml**

```xml
<!-- android/app/src/main/res/drawable/widget_disc_pill_done.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#D4AF64" />
    <corners android:radius="8dp" />
</shape>
```

```xml
<!-- android/app/src/main/res/drawable/widget_disc_pill_undone.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#0D0A05" />
    <corners android:radius="8dp" />
    <stroke android:width="1dp" android:color="#3A3020" />
</shape>
```

- [ ] **Step 5: Create button drawables**

```xml
<!-- android/app/src/main/res/drawable/widget_btn_gold_fill.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient android:angle="135" android:startColor="#D4AF64" android:endColor="#A07830" />
    <corners android:radius="10dp" />
</shape>
```

```xml
<!-- android/app/src/main/res/drawable/widget_btn_gold_outline.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#00000000" />
    <corners android:radius="10dp" />
    <stroke android:width="1dp" android:color="#D4AF64" />
</shape>
```

```xml
<!-- android/app/src/main/res/drawable/widget_btn_stop.xml -->
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <solid android:color="#00000000" />
    <corners android:radius="10dp" />
    <stroke android:width="1dp" android:color="#C97B5A" />
</shape>
```

- [ ] **Step 6: Create widget_cross_watermark.xml**

```xml
<!-- android/app/src/main/res/drawable/widget_cross_watermark.xml -->
<?xml version="1.0" encoding="utf-8"?>
<layer-list xmlns:android="http://schemas.android.com/apk/res/android">
    <item>
        <shape android:shape="rectangle">
            <solid android:color="#00000000" />
        </shape>
    </item>
</layer-list>
```

Note: True cross watermark at 10% opacity is difficult with pure XML shapes. Use a simple transparent placeholder — the visual is achieved by a faint "✝" TextView at `alpha="0.1"` in the layout XML instead.

- [ ] **Step 7: Update English strings.xml with all widget strings**

```xml
<!-- android/app/src/main/res/values/strings.xml -->
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- Legacy (keep) -->
    <string name="widget_description">Your spiritual dashboard — disciplines, timer, streak &amp; daily scripture at a glance</string>

    <!-- Scripture Card -->
    <string name="widget_scripture_desc">Daily scripture card — verse, proclamation &amp; your word for today</string>
    <string name="widget_daily_verse">Daily Verse</string>
    <string name="widget_proclamation_label">Proclamation</string>
    <string name="widget_your_word_today">Your Word Today</string>
    <string name="widget_proclamation_text">JESUS CHRIST IS THE LORD</string>

    <!-- Discipline Bar -->
    <string name="widget_discipline_bar_desc">Quick-toggle disciplines &amp; track your daily progress</string>

    <!-- Full Altar -->
    <string name="widget_full_altar_desc">Complete dashboard — scripture, disciplines &amp; timer controls</string>
    <string name="widget_start_timer">Start Timer</string>
    <string name="widget_open_log">Open Log</string>
    <string name="widget_keep_streak">Keep your streak alive!</string>
    <string name="widget_days_this_week">%1$d of 7 days this week</string>
    <string name="widget_prayer">Prayer</string>
    <string name="widget_bible">Bible</string>
    <string name="widget_literature">Literature</string>

    <!-- Proclamation Counter -->
    <string name="widget_proclamation_counter_desc">Tap to proclaim — Jesus Christ is the Lord</string>
    <string name="widget_proclamations_today">Proclamations Today</string>
</resources>
```

- [ ] **Step 8: Create French strings.xml**

```xml
<!-- android/app/src/main/res/values-fr/strings.xml -->
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="widget_description">Votre tableau spirituel — disciplines, chronomètre, série &amp; écriture quotidienne</string>

    <!-- Scripture Card -->
    <string name="widget_scripture_desc">Carte d\'écriture quotidienne — verset, proclamation &amp; votre parole du jour</string>
    <string name="widget_daily_verse">Verset du Jour</string>
    <string name="widget_proclamation_label">Proclamation</string>
    <string name="widget_your_word_today">Votre Parole Aujourd\'hui</string>
    <string name="widget_proclamation_text">JÉSUS-CHRIST EST LE SEIGNEUR</string>

    <!-- Discipline Bar -->
    <string name="widget_discipline_bar_desc">Basculer les disciplines &amp; suivre vos progrès quotidiens</string>

    <!-- Full Altar -->
    <string name="widget_full_altar_desc">Tableau complet — écriture, disciplines &amp; contrôles du chronomètre</string>
    <string name="widget_start_timer">Démarrer</string>
    <string name="widget_open_log">Ouvrir Journal</string>
    <string name="widget_keep_streak">Maintenez votre série!</string>
    <string name="widget_days_this_week">%1$d sur 7 jours cette semaine</string>
    <string name="widget_prayer">Prière</string>
    <string name="widget_bible">Bible</string>
    <string name="widget_literature">Littérature</string>

    <!-- Proclamation Counter -->
    <string name="widget_proclamation_counter_desc">Appuyez pour proclamer — Jésus-Christ est le Seigneur</string>
    <string name="widget_proclamations_today">Proclamations Aujourd\'hui</string>
</resources>
```

- [ ] **Step 9: Commit**

```bash
git add android/app/src/main/res/drawable/widget_altar_bg.xml \
        android/app/src/main/res/drawable/widget_altar_bg_darker.xml \
        android/app/src/main/res/drawable/widget_gold_divider.xml \
        android/app/src/main/res/drawable/widget_disc_pill_done.xml \
        android/app/src/main/res/drawable/widget_disc_pill_undone.xml \
        android/app/src/main/res/drawable/widget_btn_gold_fill.xml \
        android/app/src/main/res/drawable/widget_btn_gold_outline.xml \
        android/app/src/main/res/drawable/widget_btn_stop.xml \
        android/app/src/main/res/drawable/widget_cross_watermark.xml \
        android/app/src/main/res/values/strings.xml \
        android/app/src/main/res/values-fr/strings.xml
git commit -m "feat(widget): add shared drawables and bilingual string resources for Living Altar widgets"
```

---

### Task 2: WidgetHelper.kt — Shared Utility Class

Create the shared Kotlin utility used by all four widget providers for locale resolution, string fetching, scripture content, and SharedPreferences data reading.

**Files:**
- Create: `android/app/src/main/kotlin/com/example/daily_account/WidgetHelper.kt`
- Create: `assets/verses.json`
- Modify: `pubspec.yaml` (register assets/ directory)

**Interfaces:**
- Consumes: `R.string.widget_*` string resources from Task 1
- Produces: `WidgetHelper` object with methods:
  - `getLocale(widgetData: SharedPreferences): String` — returns `"en"` or `"fr"`
  - `getLocalizedString(context: Context, locale: String, resId: Int): String` — returns string for given locale
  - `getScripture(context: Context, widgetData: SharedPreferences, locale: String): Pair<String, String>` — returns (text, label) based on time of day
  - `getDisciplineLabel(index: Int): String` — returns 3-letter abbreviation (BIB, LIT, DDG, PRY, EVG)
  - `GOLD`, `SAND`, `CLAY`, `GREEN`, `ESPRESSO`, `DEEP_BG` — color constants

- [ ] **Step 1: Create verses.json with bilingual daily verses**

Create `assets/verses.json` with 14 seed verses (2 per day of week). The full 365 can be expanded later. Each entry has `en` and `fr` fields plus a `ref` field.

```json
[
  {"ref": "Psalm 119:105", "en": "Your word is a lamp to my feet and a light to my path.", "fr": "Ta parole est une lampe à mes pieds et une lumière sur mon sentier."},
  {"ref": "Proverbs 3:5-6", "en": "Trust in the Lord with all your heart and lean not on your own understanding.", "fr": "Confie-toi en l'Éternel de tout ton cœur, et ne t'appuie pas sur ta sagesse."},
  {"ref": "Joshua 1:9", "en": "Be strong and courageous. Do not be afraid, for the Lord your God is with you.", "fr": "Fortifie-toi et prends courage! Ne t'effraie point, car l'Éternel ton Dieu est avec toi."},
  {"ref": "Philippians 4:13", "en": "I can do all things through Christ who strengthens me.", "fr": "Je puis tout par celui qui me fortifie."},
  {"ref": "Romans 8:28", "en": "All things work together for good to those who love God.", "fr": "Toutes choses concourent au bien de ceux qui aiment Dieu."},
  {"ref": "Isaiah 40:31", "en": "Those who wait on the Lord shall renew their strength.", "fr": "Ceux qui se confient en l'Éternel renouvellent leur force."},
  {"ref": "Jeremiah 29:11", "en": "For I know the plans I have for you, declares the Lord.", "fr": "Car je connais les projets que j'ai formés sur vous, dit l'Éternel."},
  {"ref": "Matthew 6:33", "en": "Seek first the kingdom of God and his righteousness.", "fr": "Cherchez premièrement le royaume et la justice de Dieu."},
  {"ref": "2 Timothy 1:7", "en": "God has not given us a spirit of fear, but of power, love, and self-discipline.", "fr": "Dieu ne nous a pas donné un esprit de timidité, mais de force, d'amour et de sagesse."},
  {"ref": "Psalm 23:1", "en": "The Lord is my shepherd; I shall not want.", "fr": "L'Éternel est mon berger: je ne manquerai de rien."},
  {"ref": "Hebrews 11:1", "en": "Faith is the substance of things hoped for, the evidence of things not seen.", "fr": "La foi est une ferme assurance des choses qu'on espère, une démonstration de celles qu'on ne voit pas."},
  {"ref": "Romans 12:2", "en": "Do not be conformed to this world, but be transformed by the renewal of your mind.", "fr": "Ne vous conformez pas au siècle présent, mais soyez transformés par le renouvellement de l'intelligence."},
  {"ref": "Psalm 46:10", "en": "Be still, and know that I am God.", "fr": "Arrêtez, et sachez que je suis Dieu."},
  {"ref": "Revelation 2:10", "en": "Be faithful unto death, and I will give you the crown of life.", "fr": "Sois fidèle jusqu'à la mort, et je te donnerai la couronne de vie."}
]
```

- [ ] **Step 2: Register assets in pubspec.yaml**

In `pubspec.yaml`, under the `flutter:` > `assets:` section, add:

```yaml
    - assets/verses.json
```

- [ ] **Step 3: Create WidgetHelper.kt**

```kotlin
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
```

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/example/daily_account/WidgetHelper.kt \
        assets/verses.json \
        pubspec.yaml
git commit -m "feat(widget): add WidgetHelper utility and bilingual verses.json"
```

---

### Task 3: Scripture Card Widget (2x2)

Create the Scripture Card — a beautiful 2x2 widget showing time-aware scripture with gold-on-espresso styling.

**Files:**
- Create: `android/app/src/main/res/layout/widget_scripture_card.xml`
- Create: `android/app/src/main/res/xml/appwidget_info_scripture.xml`
- Create: `android/app/src/main/kotlin/com/example/daily_account/ScriptureWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `WidgetHelper.getScripture()`, `WidgetHelper.getLocale()`, `WidgetHelper.getLocalizedString()` from Task 2
- Consumes: `@drawable/widget_altar_bg`, `@drawable/widget_gold_divider` from Task 1
- Produces: `ScriptureWidgetProvider` class registered in manifest, updatable via `HomeWidget.updateWidget(androidName: 'ScriptureWidgetProvider')`

- [ ] **Step 1: Create appwidget_info_scripture.xml**

```xml
<!-- android/app/src/main/res/xml/appwidget_info_scripture.xml -->
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_scripture_card"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:previewLayout="@layout/widget_scripture_card"
    android:widgetCategory="home_screen"
    android:description="@string/widget_scripture_desc" />
```

- [ ] **Step 2: Create widget_scripture_card.xml layout**

```xml
<!-- android/app/src/main/res/layout/widget_scripture_card.xml -->
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/scripture_container"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_altar_bg"
    android:padding="12dp">

    <!-- Cross watermark at 10% opacity -->
    <TextView
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:gravity="center"
        android:text="✝"
        android:textSize="48sp"
        android:textColor="#1AD4AF64"
        android:alpha="0.1" />

    <!-- Scripture text — centered vertically -->
    <TextView
        android:id="@+id/scripture_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_centerInParent="true"
        android:layout_above="@+id/scripture_divider"
        android:layout_marginBottom="8dp"
        android:gravity="center"
        android:text="Your word is a lamp to my feet..."
        android:textColor="#D4AF64"
        android:textSize="13sp"
        android:fontFamily="serif"
        android:textStyle="italic"
        android:maxLines="4"
        android:ellipsize="end" />

    <!-- Scripture reference -->
    <TextView
        android:id="@+id/scripture_ref"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_below="@id/scripture_text"
        android:layout_above="@+id/scripture_divider"
        android:gravity="center"
        android:text="— Psalm 119:105"
        android:textColor="#A09070"
        android:textSize="10sp"
        android:fontFamily="serif"
        android:layout_marginBottom="8dp" />

    <!-- Gold divider -->
    <View
        android:id="@+id/scripture_divider"
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:layout_above="@+id/scripture_label"
        android:layout_marginBottom="4dp"
        android:background="@drawable/widget_gold_divider" />

    <!-- Label: "Daily Verse" or "Proclamation" -->
    <TextView
        android:id="@+id/scripture_label"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_alignParentBottom="true"
        android:gravity="center"
        android:text="DAILY VERSE"
        android:textColor="#7A6A4A"
        android:textSize="8sp"
        android:fontFamily="serif"
        android:textAllCaps="true"
        android:letterSpacing="0.15" />

</RelativeLayout>
```

- [ ] **Step 3: Create ScriptureWidgetProvider.kt**

```kotlin
// android/app/src/main/kotlin/com/example/daily_account/ScriptureWidgetProvider.kt
package com.example.daily_account

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
                views.setTextViewText(R.id.scripture_ref, "— $ref")
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
```

- [ ] **Step 4: Add receiver to AndroidManifest.xml**

Add this block inside `<application>`, after the existing `DailyAccountWidgetProvider` receiver:

```xml
        <!-- Scripture Card widget (2x2) -->
        <receiver android:name=".ScriptureWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/appwidget_info_scripture"/>
        </receiver>
```

- [ ] **Step 5: Verify build compiles**

Run: `cd android && ./gradlew assembleDebug`

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/layout/widget_scripture_card.xml \
        android/app/src/main/res/xml/appwidget_info_scripture.xml \
        android/app/src/main/kotlin/com/example/daily_account/ScriptureWidgetProvider.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): add Scripture Card widget (2x2) with time-aware content rotation"
```

---

### Task 4: Discipline Bar Widget (4x2)

Create the Discipline Bar — a compact 4x2 widget with completion ring, streak, and 5 toggleable discipline icons.

**Files:**
- Create: `android/app/src/main/res/layout/widget_discipline_bar.xml`
- Create: `android/app/src/main/res/xml/appwidget_info_discipline_bar.xml`
- Create: `android/app/src/main/kotlin/com/example/daily_account/DisciplineBarWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `WidgetHelper.getCompletion()`, `WidgetHelper.getStreak()`, `WidgetHelper.completionColor()`, `WidgetHelper.DISC_KEYS_PREFS`, `WidgetHelper.DISC_KEYS_TOGGLE`, `WidgetHelper.DISC_LABELS` from Task 2
- Consumes: `@drawable/widget_altar_bg`, `@drawable/widget_disc_pill_done`, `@drawable/widget_disc_pill_undone`, `@drawable/widget_progress_bg` from Task 1
- Produces: `DisciplineBarWidgetProvider` class registered in manifest

- [ ] **Step 1: Create appwidget_info_discipline_bar.xml**

```xml
<!-- android/app/src/main/res/xml/appwidget_info_discipline_bar.xml -->
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_discipline_bar"
    android:minWidth="250dp"
    android:minHeight="80dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:previewLayout="@layout/widget_discipline_bar"
    android:widgetCategory="home_screen"
    android:description="@string/widget_discipline_bar_desc" />
```

- [ ] **Step 2: Create widget_discipline_bar.xml layout**

```xml
<!-- android/app/src/main/res/layout/widget_discipline_bar.xml -->
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/disc_bar_container"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_altar_bg"
    android:gravity="center_vertical"
    android:orientation="horizontal"
    android:padding="10dp">

    <!-- Left: Completion ring + streak -->
    <LinearLayout
        android:id="@+id/disc_bar_ring_area"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:gravity="center"
        android:orientation="vertical"
        android:layout_marginEnd="10dp">

        <FrameLayout
            android:layout_width="56dp"
            android:layout_height="56dp">

            <ImageView
                android:layout_width="56dp"
                android:layout_height="56dp"
                android:src="@drawable/widget_progress_bg"
                android:contentDescription="Progress" />

            <TextView
                android:id="@+id/disc_bar_completion"
                android:layout_width="match_parent"
                android:layout_height="match_parent"
                android:gravity="center"
                android:text="0%"
                android:textColor="#D4AF64"
                android:textSize="16sp"
                android:fontFamily="serif"
                android:textStyle="bold" />
        </FrameLayout>

        <TextView
            android:id="@+id/disc_bar_streak"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginTop="2dp"
            android:text="🔥 0"
            android:textColor="#A09070"
            android:textSize="10sp" />
    </LinearLayout>

    <!-- Right: 5 discipline icons in a row -->
    <LinearLayout
        android:layout_width="0dp"
        android:layout_height="wrap_content"
        android:layout_weight="1"
        android:gravity="center"
        android:orientation="horizontal">

        <!-- Bible -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="vertical">
            <TextView
                android:id="@+id/disc_bar_ic_bible"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:gravity="center"
                android:background="@drawable/widget_disc_pill_undone"
                android:text="📖"
                android:textSize="16sp" />
            <TextView
                android:id="@+id/disc_bar_lbl_bible"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="BIB"
                android:textColor="#7A6A4A"
                android:textSize="7sp"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <!-- Literature -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="vertical">
            <TextView
                android:id="@+id/disc_bar_ic_lit"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:gravity="center"
                android:background="@drawable/widget_disc_pill_undone"
                android:text="📚"
                android:textSize="16sp" />
            <TextView
                android:id="@+id/disc_bar_lbl_lit"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="LIT"
                android:textColor="#7A6A4A"
                android:textSize="7sp"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <!-- DDEG -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="vertical">
            <TextView
                android:id="@+id/disc_bar_ic_ddeg"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:gravity="center"
                android:background="@drawable/widget_disc_pill_undone"
                android:text="🔥"
                android:textSize="16sp" />
            <TextView
                android:id="@+id/disc_bar_lbl_ddeg"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="DDG"
                android:textColor="#7A6A4A"
                android:textSize="7sp"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <!-- Prayer -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="vertical">
            <TextView
                android:id="@+id/disc_bar_ic_prayer"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:gravity="center"
                android:background="@drawable/widget_disc_pill_undone"
                android:text="🙏"
                android:textSize="16sp" />
            <TextView
                android:id="@+id/disc_bar_lbl_prayer"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="PRY"
                android:textColor="#7A6A4A"
                android:textSize="7sp"
                android:layout_marginTop="2dp" />
        </LinearLayout>

        <!-- Evangelism -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="vertical">
            <TextView
                android:id="@+id/disc_bar_ic_evangelism"
                android:layout_width="36dp"
                android:layout_height="36dp"
                android:gravity="center"
                android:background="@drawable/widget_disc_pill_undone"
                android:text="📢"
                android:textSize="16sp" />
            <TextView
                android:id="@+id/disc_bar_lbl_evangelism"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="EVG"
                android:textColor="#7A6A4A"
                android:textSize="7sp"
                android:layout_marginTop="2dp" />
        </LinearLayout>

    </LinearLayout>
</LinearLayout>
```

- [ ] **Step 3: Create DisciplineBarWidgetProvider.kt**

```kotlin
// android/app/src/main/kotlin/com/example/daily_account/DisciplineBarWidgetProvider.kt
package com.example.daily_account

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
```

- [ ] **Step 4: Add receiver to AndroidManifest.xml**

Add after the Scripture receiver:

```xml
        <!-- Discipline Bar widget (4x2) -->
        <receiver android:name=".DisciplineBarWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/appwidget_info_discipline_bar"/>
        </receiver>
```

- [ ] **Step 5: Verify build compiles**

Run: `cd android && ./gradlew assembleDebug`

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/layout/widget_discipline_bar.xml \
        android/app/src/main/res/xml/appwidget_info_discipline_bar.xml \
        android/app/src/main/kotlin/com/example/daily_account/DisciplineBarWidgetProvider.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): add Discipline Bar widget (4x2) with quick-toggle icons"
```

---

### Task 5: Full Altar Widget (4x3) with Timer Controls

Create the Full Altar — the complete dashboard combining scripture, disciplines, and adaptive timer controls with Chronometer for live elapsed time.

**Files:**
- Create: `android/app/src/main/res/layout/widget_full_altar.xml`
- Create: `android/app/src/main/res/layout/widget_full_altar_timer_idle.xml` (RemoteViews for idle state bottom zone)
- Create: `android/app/src/main/res/layout/widget_full_altar_timer_picker.xml` (RemoteViews for discipline picker)
- Create: `android/app/src/main/res/xml/appwidget_info_full_altar.xml`
- Create: `android/app/src/main/kotlin/com/example/daily_account/FullAltarWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: All `WidgetHelper` methods from Task 2
- Consumes: All drawables from Task 1
- Consumes: Discipline icons/toggle pattern from Task 4 (same approach, different view IDs)
- Produces: `FullAltarWidgetProvider` class with timer control deep links

- [ ] **Step 1: Create appwidget_info_full_altar.xml**

```xml
<!-- android/app/src/main/res/xml/appwidget_info_full_altar.xml -->
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_full_altar"
    android:minWidth="250dp"
    android:minHeight="180dp"
    android:targetCellWidth="4"
    android:targetCellHeight="3"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:previewLayout="@layout/widget_full_altar"
    android:widgetCategory="home_screen"
    android:description="@string/widget_full_altar_desc" />
```

- [ ] **Step 2: Create widget_full_altar.xml layout**

```xml
<!-- android/app/src/main/res/layout/widget_full_altar.xml -->
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/altar_container"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_altar_bg"
    android:orientation="vertical">

    <!-- ═══ TOP ZONE: Scripture Strip ═══ -->
    <LinearLayout
        android:id="@+id/altar_scripture_strip"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:background="@drawable/widget_altar_bg_darker"
        android:gravity="center_vertical"
        android:orientation="horizontal"
        android:paddingStart="12dp"
        android:paddingEnd="12dp"
        android:paddingTop="8dp"
        android:paddingBottom="8dp">

        <TextView
            android:id="@+id/altar_scripture_text"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:text="Your word is a lamp..."
            android:textColor="#D4AF64"
            android:textSize="11sp"
            android:fontFamily="serif"
            android:textStyle="italic"
            android:maxLines="1"
            android:ellipsize="end" />

        <TextView
            android:id="@+id/altar_scripture_ref"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:layout_marginStart="8dp"
            android:text="Ps 119:105"
            android:textColor="#A09070"
            android:textSize="9sp"
            android:fontFamily="serif" />
    </LinearLayout>

    <!-- Gold divider -->
    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:background="@drawable/widget_gold_divider" />

    <!-- ═══ MIDDLE ZONE: Discipline Row + Progress ═══ -->
    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:gravity="center_vertical"
        android:orientation="horizontal"
        android:paddingStart="10dp"
        android:paddingEnd="10dp"
        android:paddingTop="8dp"
        android:paddingBottom="6dp">

        <!-- Left: Completion ring + streak -->
        <LinearLayout
            android:id="@+id/altar_ring_area"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:orientation="vertical"
            android:layout_marginEnd="8dp">

            <FrameLayout
                android:layout_width="48dp"
                android:layout_height="48dp">
                <ImageView
                    android:layout_width="48dp"
                    android:layout_height="48dp"
                    android:src="@drawable/widget_progress_bg"
                    android:contentDescription="Progress" />
                <TextView
                    android:id="@+id/altar_completion"
                    android:layout_width="match_parent"
                    android:layout_height="match_parent"
                    android:gravity="center"
                    android:text="0%"
                    android:textColor="#D4AF64"
                    android:textSize="14sp"
                    android:fontFamily="serif"
                    android:textStyle="bold" />
            </FrameLayout>

            <TextView
                android:id="@+id/altar_streak"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginTop="1dp"
                android:text="🔥 0"
                android:textColor="#A09070"
                android:textSize="9sp" />
        </LinearLayout>

        <!-- Right: 5 discipline icons -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center"
            android:orientation="horizontal">

            <!-- Bible -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:gravity="center"
                android:orientation="vertical">
                <TextView
                    android:id="@+id/altar_ic_bible"
                    android:layout_width="32dp"
                    android:layout_height="32dp"
                    android:gravity="center"
                    android:background="@drawable/widget_disc_pill_undone"
                    android:text="📖"
                    android:textSize="14sp" />
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="BIB"
                    android:textColor="#7A6A4A"
                    android:textSize="6sp"
                    android:layout_marginTop="1dp" />
            </LinearLayout>

            <!-- Literature -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:gravity="center"
                android:orientation="vertical">
                <TextView
                    android:id="@+id/altar_ic_lit"
                    android:layout_width="32dp"
                    android:layout_height="32dp"
                    android:gravity="center"
                    android:background="@drawable/widget_disc_pill_undone"
                    android:text="📚"
                    android:textSize="14sp" />
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="LIT"
                    android:textColor="#7A6A4A"
                    android:textSize="6sp"
                    android:layout_marginTop="1dp" />
            </LinearLayout>

            <!-- DDEG -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:gravity="center"
                android:orientation="vertical">
                <TextView
                    android:id="@+id/altar_ic_ddeg"
                    android:layout_width="32dp"
                    android:layout_height="32dp"
                    android:gravity="center"
                    android:background="@drawable/widget_disc_pill_undone"
                    android:text="🔥"
                    android:textSize="14sp" />
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="DDG"
                    android:textColor="#7A6A4A"
                    android:textSize="6sp"
                    android:layout_marginTop="1dp" />
            </LinearLayout>

            <!-- Prayer -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:gravity="center"
                android:orientation="vertical">
                <TextView
                    android:id="@+id/altar_ic_prayer"
                    android:layout_width="32dp"
                    android:layout_height="32dp"
                    android:gravity="center"
                    android:background="@drawable/widget_disc_pill_undone"
                    android:text="🙏"
                    android:textSize="14sp" />
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="PRY"
                    android:textColor="#7A6A4A"
                    android:textSize="6sp"
                    android:layout_marginTop="1dp" />
            </LinearLayout>

            <!-- Evangelism -->
            <LinearLayout
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:gravity="center"
                android:orientation="vertical">
                <TextView
                    android:id="@+id/altar_ic_evangelism"
                    android:layout_width="32dp"
                    android:layout_height="32dp"
                    android:gravity="center"
                    android:background="@drawable/widget_disc_pill_undone"
                    android:text="📢"
                    android:textSize="14sp" />
                <TextView
                    android:layout_width="wrap_content"
                    android:layout_height="wrap_content"
                    android:text="EVG"
                    android:textColor="#7A6A4A"
                    android:textSize="6sp"
                    android:layout_marginTop="1dp" />
            </LinearLayout>
        </LinearLayout>
    </LinearLayout>

    <!-- Gold divider -->
    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:layout_marginStart="10dp"
        android:layout_marginEnd="10dp"
        android:background="@drawable/widget_gold_divider" />

    <!-- ═══ BOTTOM ZONE: Timer / Actions (adaptive) ═══ -->

    <!-- Timer IDLE state: motivational text + two buttons -->
    <LinearLayout
        android:id="@+id/altar_timer_idle"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:gravity="center"
        android:orientation="vertical"
        android:paddingStart="10dp"
        android:paddingEnd="10dp"
        android:paddingBottom="8dp">

        <!-- Motivational text -->
        <TextView
            android:id="@+id/altar_motivational"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:text="Keep your streak alive!"
            android:textColor="#A09070"
            android:textSize="9sp"
            android:fontFamily="serif"
            android:layout_marginBottom="4dp" />

        <!-- Action buttons row -->
        <LinearLayout
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
            android:gravity="center"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/altar_btn_start_timer"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:background="@drawable/widget_btn_gold_fill"
                android:gravity="center"
                android:paddingTop="7dp"
                android:paddingBottom="7dp"
                android:text="Start Timer"
                android:textColor="#0D0A05"
                android:textSize="11sp"
                android:textStyle="bold" />

            <View
                android:layout_width="6dp"
                android:layout_height="0dp" />

            <TextView
                android:id="@+id/altar_btn_open_log"
                android:layout_width="0dp"
                android:layout_height="wrap_content"
                android:layout_weight="1"
                android:background="@drawable/widget_btn_gold_outline"
                android:gravity="center"
                android:paddingTop="7dp"
                android:paddingBottom="7dp"
                android:text="Open Log"
                android:textColor="#D4AF64"
                android:textSize="11sp"
                android:textStyle="bold" />
        </LinearLayout>
    </LinearLayout>

    <!-- Timer PICKER state: 3 discipline pills -->
    <LinearLayout
        android:id="@+id/altar_timer_picker"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:gravity="center"
        android:orientation="horizontal"
        android:paddingStart="10dp"
        android:paddingEnd="10dp"
        android:paddingBottom="8dp"
        android:visibility="gone">

        <TextView
            android:id="@+id/altar_pick_prayer"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:background="@drawable/widget_btn_gold_outline"
            android:gravity="center"
            android:paddingTop="7dp"
            android:paddingBottom="7dp"
            android:text="Prayer"
            android:textColor="#D4AF64"
            android:textSize="11sp" />

        <View android:layout_width="4dp" android:layout_height="0dp" />

        <TextView
            android:id="@+id/altar_pick_bible"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:background="@drawable/widget_btn_gold_outline"
            android:gravity="center"
            android:paddingTop="7dp"
            android:paddingBottom="7dp"
            android:text="Bible"
            android:textColor="#D4AF64"
            android:textSize="11sp" />

        <View android:layout_width="4dp" android:layout_height="0dp" />

        <TextView
            android:id="@+id/altar_pick_literature"
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:background="@drawable/widget_btn_gold_outline"
            android:gravity="center"
            android:paddingTop="7dp"
            android:paddingBottom="7dp"
            android:text="Literature"
            android:textColor="#D4AF64"
            android:textSize="11sp" />
    </LinearLayout>

    <!-- Timer RUNNING state: label + chronometer + pause/stop buttons -->
    <LinearLayout
        android:id="@+id/altar_timer_running"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:gravity="center_vertical"
        android:orientation="horizontal"
        android:paddingStart="10dp"
        android:paddingEnd="10dp"
        android:paddingBottom="8dp"
        android:visibility="gone">

        <!-- Timer info -->
        <LinearLayout
            android:layout_width="0dp"
            android:layout_height="wrap_content"
            android:layout_weight="1"
            android:gravity="center_vertical"
            android:orientation="horizontal">

            <TextView
                android:id="@+id/altar_timer_dot"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text="●"
                android:textColor="#6FBF73"
                android:textSize="8sp" />

            <TextView
                android:id="@+id/altar_timer_label"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:layout_marginStart="4dp"
                android:text="Prayer"
                android:textColor="#E8D4A0"
                android:textSize="11sp"
                android:fontFamily="serif" />

            <TextView
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:text=" — "
                android:textColor="#7A6A4A"
                android:textSize="11sp" />

            <Chronometer
                android:id="@+id/altar_chronometer"
                android:layout_width="wrap_content"
                android:layout_height="wrap_content"
                android:textColor="#D4AF64"
                android:textSize="16sp"
                android:fontFamily="serif"
                android:textStyle="bold"
                android:format="%s" />
        </LinearLayout>

        <!-- Pause button -->
        <TextView
            android:id="@+id/altar_btn_pause"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/widget_btn_gold_outline"
            android:paddingStart="10dp"
            android:paddingEnd="10dp"
            android:paddingTop="6dp"
            android:paddingBottom="6dp"
            android:text="⏸"
            android:textSize="14sp"
            android:layout_marginEnd="4dp" />

        <!-- Stop button -->
        <TextView
            android:id="@+id/altar_btn_stop"
            android:layout_width="wrap_content"
            android:layout_height="wrap_content"
            android:background="@drawable/widget_btn_stop"
            android:paddingStart="10dp"
            android:paddingEnd="10dp"
            android:paddingTop="6dp"
            android:paddingBottom="6dp"
            android:text="⏹"
            android:textSize="14sp" />
    </LinearLayout>

</LinearLayout>
```

- [ ] **Step 3: Create FullAltarWidgetProvider.kt**

```kotlin
// android/app/src/main/kotlin/com/example/daily_account/FullAltarWidgetProvider.kt
package com.example.daily_account

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
                    val timerStartMs = widgetData.getString("timer_start_ms", "0")?.toLongOrNull() ?: 0L
                    // Chronometer counts UP from base. We need: base = elapsedRealtime - totalElapsed
                    // totalElapsed = elapsedMs (paused time) + (currentTime - timerStartMs)
                    // But Chronometer auto-increments from base, so:
                    // base = elapsedRealtime() - elapsedMs  (approximation for initial display)
                    val base = SystemClock.elapsedRealtime() - elapsedMs
                    views.setChronometer(R.id.altar_chronometer, base, null, true)
                    views.setTextColor(R.id.altar_timer_dot, WidgetHelper.GREEN)
                } else {
                    // Paused — show frozen time
                    val base = SystemClock.elapsedRealtime() - elapsedMs
                    views.setChronometer(R.id.altar_chronometer, base, null, false)
                    views.setTextColor(R.id.altar_timer_dot, WidgetHelper.CLAY)
                }

                // Pause button
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
                views.setTextViewText(R.id.altar_pick_prayer,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_prayer))
                views.setTextViewText(R.id.altar_pick_bible,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_bible))
                views.setTextViewText(R.id.altar_pick_literature,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_literature))

                // Picker click handlers
                val timerDisciplines = listOf("prayerAlone", "bible", "literature")
                val pickerIds = listOf(R.id.altar_pick_prayer, R.id.altar_pick_bible, R.id.altar_pick_literature)
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
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_days_this_week, daysThisWeek)
                } else {
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_keep_streak)
                }
                views.setTextViewText(R.id.altar_motivational, motivational)

                // Button labels
                views.setTextViewText(R.id.altar_btn_start_timer,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_start_timer))
                views.setTextViewText(R.id.altar_btn_open_log,
                    WidgetHelper.getLocalizedString(context, locale, R.string.widget_open_log))

                // Start Timer → show picker (save flag and update)
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
```

- [ ] **Step 4: Add receiver to AndroidManifest.xml**

Add after the Discipline Bar receiver:

```xml
        <!-- Full Altar widget (4x3) -->
        <receiver android:name=".FullAltarWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/appwidget_info_full_altar"/>
        </receiver>
```

- [ ] **Step 5: Verify build compiles**

Run: `cd android && ./gradlew assembleDebug`

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/layout/widget_full_altar.xml \
        android/app/src/main/res/xml/appwidget_info_full_altar.xml \
        android/app/src/main/kotlin/com/example/daily_account/FullAltarWidgetProvider.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): add Full Altar widget (4x3) with adaptive timer controls and Chronometer"
```

---

### Task 6: Proclamation Counter Widget (2x2)

Create the Proclamation Counter — a tap-to-increment widget displaying "JESUS CHRIST IS THE LORD" with real-time count sync.

**Files:**
- Create: `android/app/src/main/res/layout/widget_proclamation.xml`
- Create: `android/app/src/main/res/xml/appwidget_info_proclamation.xml`
- Create: `android/app/src/main/kotlin/com/example/daily_account/ProclamationWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `WidgetHelper.getLocale()`, `WidgetHelper.getLocalizedString()` from Task 2
- Consumes: `@drawable/widget_altar_bg` from Task 1
- Produces: `ProclamationWidgetProvider` class, fires `dailyaccount://proclamation/increment` on tap, `dailyaccount://open/proclamation` on long-press

- [ ] **Step 1: Create appwidget_info_proclamation.xml**

```xml
<!-- android/app/src/main/res/xml/appwidget_info_proclamation.xml -->
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:initialLayout="@layout/widget_proclamation"
    android:minWidth="110dp"
    android:minHeight="110dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:resizeMode="horizontal|vertical"
    android:updatePeriodMillis="1800000"
    android:previewLayout="@layout/widget_proclamation"
    android:widgetCategory="home_screen"
    android:description="@string/widget_proclamation_counter_desc" />
```

- [ ] **Step 2: Create widget_proclamation.xml layout**

```xml
<!-- android/app/src/main/res/layout/widget_proclamation.xml -->
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/proclamation_container"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_altar_bg"
    android:padding="12dp">

    <!-- Large counter number -->
    <TextView
        android:id="@+id/proclamation_count"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_centerInParent="true"
        android:layout_above="@+id/proclamation_text"
        android:gravity="center"
        android:text="0"
        android:textColor="#D4AF64"
        android:textSize="36sp"
        android:fontFamily="serif"
        android:textStyle="bold" />

    <!-- Proclamation text -->
    <TextView
        android:id="@+id/proclamation_text"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_centerInParent="true"
        android:gravity="center"
        android:text="JESUS CHRIST IS THE LORD"
        android:textColor="#A09070"
        android:textSize="9sp"
        android:fontFamily="serif"
        android:textAllCaps="true"
        android:letterSpacing="0.08"
        android:maxLines="2"
        android:layout_marginBottom="16dp" />

    <!-- Gold divider -->
    <View
        android:id="@+id/proclamation_divider"
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:layout_above="@+id/proclamation_label"
        android:layout_marginBottom="4dp"
        android:background="@drawable/widget_gold_divider" />

    <!-- Label -->
    <TextView
        android:id="@+id/proclamation_label"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_alignParentBottom="true"
        android:gravity="center"
        android:text="PROCLAMATIONS TODAY"
        android:textColor="#7A6A4A"
        android:textSize="7sp"
        android:fontFamily="serif"
        android:textAllCaps="true"
        android:letterSpacing="0.15" />

</RelativeLayout>
```

- [ ] **Step 3: Create ProclamationWidgetProvider.kt**

```kotlin
// android/app/src/main/kotlin/com/example/daily_account/ProclamationWidgetProvider.kt
package com.example.daily_account

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

            // Tap → increment
            val incrementIntent = (launchIntent?.clone() as? Intent ?: Intent()).apply {
                data = Uri.parse("dailyaccount://proclamation/increment")
            }
            val incrementPending = PendingIntent.getActivity(
                context, 400, incrementIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.proclamation_container, incrementPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
```

Note: Android widgets don't support `onLongClick` via RemoteViews/PendingIntent. The tap-to-increment is the primary interaction. Users can access the full proclamation screen from the app's main navigation.

- [ ] **Step 4: Add receiver to AndroidManifest.xml**

Add after the Full Altar receiver:

```xml
        <!-- Proclamation Counter widget (2x2) -->
        <receiver android:name=".ProclamationWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/appwidget_info_proclamation"/>
        </receiver>
```

- [ ] **Step 5: Verify build compiles**

Run: `cd android && ./gradlew assembleDebug`

Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/res/layout/widget_proclamation.xml \
        android/app/src/main/res/xml/appwidget_info_proclamation.xml \
        android/app/src/main/kotlin/com/example/daily_account/ProclamationWidgetProvider.kt \
        android/app/src/main/AndroidManifest.xml
git commit -m "feat(widget): add Proclamation Counter widget (2x2) with tap-to-increment"
```

---

### Task 7: Flutter Integration — Widget Data Push and Deep Link Handling

Wire up the Flutter side: push all widget data on every state change, handle all deep link URIs (discipline toggle, timer control, proclamation increment, timer picker), and save `widget_locale` on language changes.

**Files:**
- Modify: `lib/screens/home_shell.dart`
- Modify: `lib/screens/log_screen.dart`
- Modify: `lib/screens/settings_screen.dart`
- Modify: `lib/services/timer_service.dart`

**Interfaces:**
- Consumes: `HomeWidget.saveWidgetData()`, `HomeWidget.updateWidget()`, `HomeWidget.widgetClicked` from `home_widget` package
- Consumes: `TimerService.instance` — `start()`, `pause()`, `stop()`, `activeKey`, `getSession()`
- Consumes: `StorageService.instance` — `getLog()`, `saveLog()`, `getSetting()`, `setSetting()`
- Consumes: `DailyLog` model — `proclamationCount`, `ddegScripture` fields
- Produces: Updated `_updateHomeWidget()` pushing all data keys from the spec
- Produces: Deep link handlers for `timer/start/*`, `timer/pause`, `timer/stop`, `timer/picker`, `proclamation/increment`
- Produces: `widget_locale` saved on language changes in Settings

- [ ] **Step 1: Update `_updateHomeWidget()` in home_shell.dart to push all new widget data keys**

In `lib/screens/home_shell.dart`, replace the existing `_updateHomeWidget()` method (lines 291-357) with this expanded version:

```dart
  Future<void> _updateHomeWidget() async {
    if (!Platform.isAndroid) return;
    try {
      final todayKey = _key(DateTime.now());
      final log = await StorageService.instance.getLog(todayKey);
      final pct = log != null ? (log.completeness * 100).round() : 0;
      final streak = await ReportService.instance.computeStreak();

      await HomeWidget.saveWidgetData('completion', '$pct');
      await HomeWidget.saveWidgetData('streak', '$streak days');

      // Individual discipline flags (1 = done, 0 = not done)
      final hasBible = log != null && (log.bibleReference.isNotEmpty || log.bibleChapters.isNotEmpty);
      final hasLit = log != null && log.literature.any((l) => l.title.isNotEmpty);
      final hasDdeg = log != null && (log.ddegScripture.isNotEmpty || log.ddegNotes.isNotEmpty);
      final hasPrayer = log != null && (log.prayerAloneDuration.isNotEmpty || log.prayerOthersDuration.isNotEmpty);
      final hasEvangelism = log != null && log.evangelismContacts.isNotEmpty;
      final hasFasting = log != null && (log.fastingType.isNotEmpty || log.fastingDuration.isNotEmpty);
      final hasGiving = log != null && log.givingType.isNotEmpty;
      final hasChurch = log != null && log.churchType.isNotEmpty;
      final hasDisciple = log != null && log.discipleshipWho.isNotEmpty;
      final hasProclamation = log != null && log.proclamationCount.isNotEmpty;

      final doneFlags = [hasBible, hasLit, hasDdeg, hasPrayer, hasEvangelism,
          hasFasting, hasGiving, hasChurch, hasDisciple, hasProclamation];
      final doneCount = doneFlags.where((f) => f).length;

      await HomeWidget.saveWidgetData('d_bible', hasBible ? '1' : '0');
      await HomeWidget.saveWidgetData('d_lit', hasLit ? '1' : '0');
      await HomeWidget.saveWidgetData('d_ddeg', hasDdeg ? '1' : '0');
      await HomeWidget.saveWidgetData('d_prayer', hasPrayer ? '1' : '0');
      await HomeWidget.saveWidgetData('d_evangelism', hasEvangelism ? '1' : '0');
      await HomeWidget.saveWidgetData('d_fasting', hasFasting ? '1' : '0');
      await HomeWidget.saveWidgetData('d_giving', hasGiving ? '1' : '0');
      await HomeWidget.saveWidgetData('d_church', hasChurch ? '1' : '0');
      await HomeWidget.saveWidgetData('d_disciple', hasDisciple ? '1' : '0');
      await HomeWidget.saveWidgetData('d_proclamation', hasProclamation ? '1' : '0');
      await HomeWidget.saveWidgetData('done_count', '$doneCount');

      // Proclamation count (numeric for counter widget)
      final procCount = log?.proclamationCount ?? '0';
      await HomeWidget.saveWidgetData('proclamation_count',
          procCount.isNotEmpty ? procCount : '0');

      // DDEG scripture (for scripture card DDEG override)
      final ddegScripture = log?.ddegScripture ?? '';
      await HomeWidget.saveWidgetData('ddeg_scripture', ddegScripture);

      // Active timer info
      final ts = TimerService.instance;
      final activeKey = ts.activeKey;
      if (activeKey != null) {
        final session = ts.getSession(activeKey);
        final label = ts.timerLabelResolver?.call(activeKey) ?? 'Timer';
        final elapsed = session != null
            ? _formatDuration(session.elapsed)
            : '';
        final elapsedMs = session?.currentElapsed.inMilliseconds ?? 0;
        await HomeWidget.saveWidgetData('timer_active', '1');
        await HomeWidget.saveWidgetData('timer_paused', '0');
        await HomeWidget.saveWidgetData('timer_label', label);
        await HomeWidget.saveWidgetData('timer_elapsed', elapsed);
        await HomeWidget.saveWidgetData('timer_elapsed_ms', '$elapsedMs');
        await HomeWidget.saveWidgetData('timer_start_ms',
            '${session?.startedAt?.millisecondsSinceEpoch ?? 0}');
      } else {
        // Check for paused timer
        TimerKey? pausedKey;
        for (final entry in ts.sessions.entries) {
          if (entry.value.paused) {
            pausedKey = entry.key;
            break;
          }
        }
        if (pausedKey != null) {
          final session = ts.getSession(pausedKey);
          final label = ts.timerLabelResolver?.call(pausedKey) ?? 'Timer';
          final elapsedMs = session?.elapsed.inMilliseconds ?? 0;
          await HomeWidget.saveWidgetData('timer_active', '0');
          await HomeWidget.saveWidgetData('timer_paused', '1');
          await HomeWidget.saveWidgetData('timer_label', label);
          await HomeWidget.saveWidgetData('timer_elapsed_ms', '$elapsedMs');
        } else {
          await HomeWidget.saveWidgetData('timer_active', '0');
          await HomeWidget.saveWidgetData('timer_paused', '0');
        }
      }

      // Reset timer picker flag
      await HomeWidget.saveWidgetData('show_timer_picker', '0');

      // Days logged this week (for motivational text)
      final daysThisWeek = await _countDaysThisWeek();
      await HomeWidget.saveWidgetData('days_this_week', '$daysThisWeek');

      // Widget locale
      final widgetLocale = await StorageService.instance.getSetting('appLocale',
          fallback: 'en');
      await HomeWidget.saveWidgetData('widget_locale', widgetLocale);

      // Daily rotating scripture (for legacy widget)
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final scripture = _widgetScriptures[dayOfYear % _widgetScriptures.length];
      await HomeWidget.saveWidgetData('scripture', scripture);

      // Update ALL widget providers
      await HomeWidget.updateWidget(androidName: 'DailyAccountWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'ScriptureWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'DisciplineBarWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
      await HomeWidget.updateWidget(androidName: 'ProclamationWidgetProvider');
    } catch (_) {
      // Widget not available — ignore
    }
  }

  /// Count how many days this week have at least one discipline logged.
  Future<int> _countDaysThisWeek() async {
    final storage = StorageService.instance;
    int count = 0;
    for (int i = 0; i < 7; i++) {
      final day = _weekMonday.add(Duration(days: i));
      if (day.isAfter(DateTime.now())) break;
      final log = await storage.getLog(_key(day));
      if (log != null && log.completeness > 0) count++;
    }
    return count;
  }
```

- [ ] **Step 2: Expand `_handleWidgetClicks()` to handle timer and proclamation deep links**

In `lib/screens/home_shell.dart`, replace the existing `_handleWidgetClicks()` method (lines 52-66) with:

```dart
  /// Listen for widget click deep links.
  void _handleWidgetClicks() {
    HomeWidget.widgetClicked.listen((uri) {
      if (uri == null) return;
      _processWidgetUri(uri);
    });
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri == null) return;
      _processWidgetUri(uri);
    });
  }

  void _processWidgetUri(Uri uri) {
    switch (uri.host) {
      case 'toggle':
        if (uri.pathSegments.isNotEmpty) {
          _toggleDisciplineFromWidget(uri.pathSegments.first);
        }
      case 'timer':
        if (uri.pathSegments.isNotEmpty) {
          _handleTimerFromWidget(uri.pathSegments);
        }
      case 'proclamation':
        if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.first == 'increment') {
          _incrementProclamationFromWidget();
        }
      case 'open':
        if (uri.pathSegments.isNotEmpty) {
          switch (uri.pathSegments.first) {
            case 'log':
              setState(() => _tab = 1);
            case 'proclamation':
              setState(() => _tab = 1); // Open to log (proclamation is in log)
          }
        }
    }
  }

  /// Handle timer deep links from the widget.
  Future<void> _handleTimerFromWidget(List<String> segments) async {
    final action = segments.first;
    final ts = TimerService.instance;

    switch (action) {
      case 'start':
        if (segments.length > 1) {
          final discipline = segments[1];
          // Map discipline string to ActivityType
          ActivityType? activity;
          switch (discipline) {
            case 'prayerAlone':
              activity = ActivityType.prayerAlone;
            case 'bible':
              activity = ActivityType.bible;
            case 'literature':
              activity = ActivityType.literature;
          }
          if (activity != null) {
            ts.startBuiltIn(activity);
            await HomeWidget.saveWidgetData('show_timer_picker', '0');
            _updateHomeWidget();
          }
        }
      case 'pause':
        final running = ts.activeKey;
        if (running != null) {
          ts.pause(running);
        } else {
          // Resume paused timer
          for (final entry in ts.sessions.entries) {
            if (entry.value.paused) {
              ts.start(entry.key);
              break;
            }
          }
        }
        _updateHomeWidget();
      case 'stop':
        final running = ts.activeKey;
        if (running != null) {
          await ts.stop(running);
        } else {
          // Stop any paused timer
          for (final key in ts.sessions.keys.toList()) {
            await ts.stop(key);
          }
        }
        _onDataChanged();
      case 'picker':
        // Show timer discipline picker on widget
        await HomeWidget.saveWidgetData('show_timer_picker', '1');
        await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
    }
  }

  /// Increment proclamation count from widget tap.
  Future<void> _incrementProclamationFromWidget() async {
    final key = _key(DateTime.now());
    final storage = StorageService.instance;
    final existing = await storage.getLog(key);
    final log = existing ?? DailyLog(dateKey: key);

    final current = int.tryParse(log.proclamationCount) ?? 0;
    log.proclamationCount = '${current + 1}';

    await storage.saveLog(log);
    _onDataChanged();
  }
```

- [ ] **Step 3: Add widget update call to `_persist()` in log_screen.dart**

In `lib/screens/log_screen.dart`, modify the `_persist()` method to trigger widget updates:

```dart
  void _persist() {
    StorageService.instance.saveLog(_log);
    widget.onChanged();
  }
```

The widget update is already triggered by `widget.onChanged()` which calls `_onDataChanged()` in home_shell.dart, which calls `_updateHomeWidget()`. No change needed — the chain already works.

- [ ] **Step 4: Save `widget_locale` when language changes in settings_screen.dart**

In `lib/screens/settings_screen.dart`, find where the app locale is changed (the language selection section) and add a widget update call. Look for the locale change handler and add after the locale is saved:

```dart
// After saving the locale setting, also save widget_locale
await HomeWidget.saveWidgetData('widget_locale', code);
await HomeWidget.updateWidget(androidName: 'ScriptureWidgetProvider');
await HomeWidget.updateWidget(androidName: 'FullAltarWidgetProvider');
await HomeWidget.updateWidget(androidName: 'ProclamationWidgetProvider');
```

Add `import 'package:home_widget/home_widget.dart';` at the top of settings_screen.dart if not already present.

- [ ] **Step 5: Add TimerService listener for widget updates in home_shell.dart**

In `lib/screens/home_shell.dart`, add a `TimerService` listener in `initState()` to push widget updates on every timer tick (once per second when a timer is running):

Add after `_handleWidgetClicks();` in `initState()`:

```dart
    // Update widget on timer ticks
    TimerService.instance.addListener(_onTimerTick);
```

Add the method:

```dart
  void _onTimerTick() {
    _updateHomeWidget();
  }
```

Add in `dispose()`:

```dart
    TimerService.instance.removeListener(_onTimerTick);
```

Note: This updates all widgets every second when a timer runs, which keeps the legacy widget's elapsed time display in sync. The Full Altar widget uses Chronometer for live display, so it doesn't strictly need per-second updates, but this ensures the data stays consistent.

- [ ] **Step 6: Verify app compiles**

Run: `flutter analyze`

Expected: 0 errors

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home_shell.dart \
        lib/screens/settings_screen.dart
git commit -m "feat(widget): wire Flutter integration — widget data push, deep link handlers, timer control, proclamation increment"
```

---

### Task 8: Cleanup — Remove Legacy Widget (Optional) and Manual Test

Remove the old `DailyAccountWidgetProvider` and its layout, verify all four new widgets work on device.

**Files:**
- Delete: `android/app/src/main/kotlin/com/example/daily_account/DailyAccountWidgetProvider.kt`
- Delete: `android/app/src/main/res/layout/daily_account_widget.xml`
- Delete: `android/app/src/main/res/xml/daily_account_widget_info.xml`
- Modify: `android/app/src/main/AndroidManifest.xml` (remove old receiver)
- Modify: `lib/screens/home_shell.dart` (remove old `updateWidget` call for `DailyAccountWidgetProvider`)

**Interfaces:**
- Consumes: All four new widgets from Tasks 3-7
- Produces: Clean manifest with only four new widget receivers

- [ ] **Step 1: Remove old widget receiver from AndroidManifest.xml**

Remove this block from `AndroidManifest.xml`:

```xml
        <!-- Home screen widget -->
        <receiver android:name=".DailyAccountWidgetProvider"
            android:exported="true">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE"/>
            </intent-filter>
            <meta-data
                android:name="android.appwidget.provider"
                android:resource="@xml/daily_account_widget_info"/>
        </receiver>
```

- [ ] **Step 2: Delete old provider and layout files**

Delete:
- `android/app/src/main/kotlin/com/example/daily_account/DailyAccountWidgetProvider.kt`
- `android/app/src/main/res/layout/daily_account_widget.xml`
- `android/app/src/main/res/xml/daily_account_widget_info.xml`

- [ ] **Step 3: Remove legacy widget update call from home_shell.dart**

In `_updateHomeWidget()`, remove the line:

```dart
      await HomeWidget.updateWidget(androidName: 'DailyAccountWidgetProvider');
```

Also remove the `_widgetScriptures` list and the legacy `scripture` data push — these are superseded by `verses.json`:

```dart
      // Remove these lines:
      final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
      final scripture = _widgetScriptures[dayOfYear % _widgetScriptures.length];
      await HomeWidget.saveWidgetData('scripture', scripture);
```

And remove the `_widgetScriptures` array definition (around lines 278-289).

- [ ] **Step 4: Clean up unused old drawable files**

Delete these files that were only used by the old widget layout:
- `android/app/src/main/res/drawable/widget_background.xml` (replaced by `widget_altar_bg.xml`)
- `android/app/src/main/res/drawable/widget_btn_log.xml` (replaced by `widget_btn_gold_fill.xml`)
- `android/app/src/main/res/drawable/widget_btn_timer.xml` (replaced by `widget_btn_gold_outline.xml`)
- `android/app/src/main/res/drawable/widget_button_bg.xml` (unused)
- `android/app/src/main/res/drawable/widget_timer_bg.xml` (replaced by in-layout styling)
- `android/app/src/main/res/drawable/widget_scripture_bg.xml` (replaced by `widget_altar_bg_darker.xml`)

Keep: `widget_disc_done.xml`, `widget_disc_undone.xml`, `widget_progress_bg.xml` — these are still used or could be referenced.

- [ ] **Step 5: Verify build compiles**

Run: `flutter analyze && cd android && ./gradlew assembleDebug`

Expected: 0 errors, BUILD SUCCESSFUL

- [ ] **Step 6: Manual test on device/emulator**

Test checklist:
1. Long-press home screen → Widgets → find "Daily Account" → see 4 widget options
2. Add Scripture Card (2x2) → verify espresso+gold styling, scripture text shows
3. Add Discipline Bar (4x2) → tap discipline icons → verify toggle works (icon changes)
4. Add Full Altar (4x3) → verify scripture strip, discipline row, timer controls
5. Full Altar: tap "Start Timer" → see discipline picker → tap "Prayer" → timer starts with live Chronometer
6. Full Altar: tap pause → timer pauses → tap play → resumes → tap stop → saves to log
7. Add Proclamation Counter (2x2) → tap → counter increments → open app → verify proclamation count matches
8. Change language in Settings → verify all widgets update text to French/English
9. Log a discipline in-app → verify all widgets update immediately

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(widget): remove legacy widget, cleanup old drawables — Living Altar system complete"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Scripture Card (2x2) with time-aware rotation → Task 3
- [x] Discipline Bar (4x2) with quick-toggle → Task 4
- [x] Full Altar (4x3) with timer controls + Chronometer → Task 5
- [x] Proclamation Counter (2x2) with tap-to-increment → Task 6
- [x] Bilingual strings (EN/FR) → Task 1
- [x] `widget_locale` SharedPreferences sync → Task 7
- [x] Real-time sync on every state change → Task 7
- [x] Deep links for toggle, timer, proclamation → Tasks 3-7
- [x] verses.json with bilingual content → Task 2
- [x] Fixed proclamation "JESUS CHRIST IS THE LORD" → Tasks 1, 2, 6
- [x] Espresso + gold visual identity → Tasks 1, 3-6
- [x] Legacy widget removal → Task 8

**Placeholder scan:** No TBDs, TODOs, or "fill in later" markers found.

**Type consistency:**
- `WidgetHelper.getLocale()` → used consistently in Tasks 3, 4, 5, 6
- `WidgetHelper.getScripture()` returns `Triple<String, String, String>` → consumed correctly in Tasks 3, 5
- `WidgetHelper.DISC_KEYS_PREFS` / `DISC_KEYS_TOGGLE` → used consistently in Tasks 4, 5
- `WidgetHelper.completionColor()` → used in Tasks 4, 5
- Deep link URIs match between Kotlin PendingIntents and Dart `_processWidgetUri()` handler
- SharedPreferences keys match between `_updateHomeWidget()` and all Kotlin providers
