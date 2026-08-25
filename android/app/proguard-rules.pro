# ============================================================
#  Daily Account — ProGuard / R8 keep rules
# ============================================================

# ── Flutter engine ──────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Google Sign-In ──────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Google APIs (googleapis / Drive) ────────────────────────
-keep class com.google.api.** { *; }
-dontwarn com.google.api.**

# ── OkHttp / Okio (used by many plugins) ───────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ── flutter_local_notifications ─────────────────────────────
-keep class com.dexterous.** { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# ── flutter_overlay_window ──────────────────────────────────
-keep class flutter.overlay.window.** { *; }

# ── local_auth (biometrics) ─────────────────────────────────
-keep class androidx.biometric.** { *; }

# ── home_widget ─────────────────────────────────────────────
-keep class es.antonborri.home_widget.** { *; }

# ── share_plus ──────────────────────────────────────────────
-keep class dev.fluttercommunity.plus.share.** { *; }

# ── file_picker ─────────────────────────────────────────────
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# ── url_launcher ────────────────────────────────────────────
-keep class io.flutter.plugins.urllauncher.** { *; }

# ── sqflite ─────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }

# ── path_provider ───────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── Kotlin serialization / reflection ───────────────────────
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── AndroidX / Jetpack ──────────────────────────────────────
-keep class androidx.** { *; }
-dontwarn androidx.**

# ── Prevent stripping Parcelable / Serializable ─────────────
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ── Keep annotations ────────────────────────────────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
