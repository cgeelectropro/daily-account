# ✝️ Daily Account — Flutter App

A beautiful spiritual accountability app for your daily walk with God, built in the CMFI discipleship tradition. Track your daily disciplines, see your faithfulness grow, and send a weekly account to your disciple maker.

---

## ✨ Features

- **📖 Daily logging** — Bible reading (reference + chapters), multiple Christian literature entries (title + pages/chapters/books), Daily Dynamic Encounter with God (DDEG scripture, time, meditation notes), prayer alone, prayer with others, evangelism (contacts, outcome, follow-up), and free-form "other" activities.
- **🔥 Faithfulness streak** — consecutive-day counter to keep you motivated.
- **📊 Weekly stats dashboard** — days logged, Bible chapters, books read, souls reached.
- **⭕ Per-day completeness ring** — see at a glance how full each day's account is.
- **⏰ Smart reminders** — a daily nudge to log + a special Sunday reminder to send.
- **📨 Multi-channel sending** — email (mailto), WhatsApp, or copy-to-clipboard fallback.
- **🔒 Private & offline** — all data stored locally in SQLite on your device.
- **🎨 Sacred "illuminated manuscript" UI** — espresso + gold-leaf palette, Cormorant Garamond + Lora typography, subtle entrance animations.

---

## 🛠 Setup (one-time)

You already have Flutter. From a terminal:

```bash
# 1. Unzip the project, then cd into it
cd daily_account

# 2. Generate the native android/ios scaffolding around this lib/
flutter create .

# 3. Get dependencies
flutter pub get
```

### Android permissions (required for reminders)

After `flutter create .`, open `android/app/src/main/AndroidManifest.xml`
and merge in the permissions and receivers from
**`AndroidManifest_ADDITIONS.xml`** (included in this project).

Also set the minimum SDK to 21+ in `android/app/build.gradle`:

```gradle
defaultConfig {
    minSdkVersion 21
}
```

---

## ▶️ Run it

```bash
# On a connected phone or emulator
flutter run

# Build a release APK you can install directly on your phone
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

Copy that APK to your phone and install it. Done — fully standalone, ~10–12 MB.

---

## 📂 Project structure

```
lib/
  main.dart                       app entry + notification init
  theme/
    app_theme.dart                colors, gradients, typography
  models/
    daily_log.dart                DailyLog + LiteratureEntry models
  services/
    storage_service.dart          SQLite + SharedPreferences
    notification_service.dart     daily & Sunday reminders
    report_service.dart           report builder, stats, streak, send
  widgets/
    common_widgets.dart           SectionCard, GoldField, ProgressRing, StatTile
  screens/
    home_shell.dart               nav, week strip, header
    log_screen.dart               daily disciplines entry
    report_screen.dart            stats dashboard + send
    settings_screen.dart          profile, contacts, reminders
```

---

## 🚀 Future upgrades (easy to add)

- **Supabase sync** so your disciple maker sees logs in real time (you're already set up with Supabase).
- **Monthly PDF report** auto-generated and shared.
- **Bible verse auto-fetch** — type a reference, pull the full verse.
- **French language toggle** 🇨🇲.
- **Voice notes** for DDEG meditation.

---

*"Give an account of thy stewardship." — Luke 16:2* 🕊️
