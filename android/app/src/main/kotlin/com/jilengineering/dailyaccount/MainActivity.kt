package com.jilengineering.dailyaccount

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private val CHANNEL = "com.jilengineering.dailyaccount/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isBatteryOptimizationDisabled" -> {
                        result.success(isBatteryOptimizationDisabled())
                    }
                    "requestDisableBatteryOptimization" -> {
                        requestDisableBatteryOptimization()
                        result.success(true)
                    }
                    "openBatteryOptimizationSettings" -> {
                        openBatteryOptimizationSettings()
                        result.success(true)
                    }
                    "getManufacturer" -> {
                        result.success(Build.MANUFACTURER.lowercase())
                    }
                    "openOemAutostartSettings" -> {
                        result.success(openOemAutostartSettings())
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true // Pre-M doesn't have battery optimization
    }

    private fun requestDisableBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        }
    }

    private fun openBatteryOptimizationSettings() {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        startActivity(intent)
    }

    /**
     * OEM Android skins (MIUI, ColorOS, FuntouchOS/OriginOS, EMUI/MagicUI, etc.)
     * enforce a second, non-stock-Android autostart/background-permission layer
     * that `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` does not touch. Without
     * whitelisting there, the OS kills scheduled alarms even with exact-alarm
     * and stock battery-optimization permission both granted. Each OEM exposes
     * its autostart manager via a different, undocumented activity, so try known
     * component names for the current manufacturer and fall back to the app's
     * details settings page (still lets the user find the setting manually).
     */
    private fun openOemAutostartSettings(): Boolean {
        val candidates = when (Build.MANUFACTURER.lowercase()) {
            "xiaomi" -> listOf(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
                ComponentName("com.miui.securitycenter", "com.miui.securitycenter.Main"),
            )
            "oppo" -> listOf(
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
                ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"),
                ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity"),
            )
            "vivo" -> listOf(
                ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
                ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager"),
            )
            "huawei", "honor" -> listOf(
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
                ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity"),
            )
            "samsung" -> listOf(
                ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity"),
            )
            "oneplus" -> listOf(
                ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
            )
            "asus" -> listOf(
                ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"),
            )
            // Transsion family (itel, Tecno, Infinix) — verified on a real
            // itel device (Android 14, HiOS): there is no separate autostart
            // manager screen. Per-app background control lives entirely
            // under the standard App Info → Battery screen (Unrestricted /
            // Optimized / Restricted), which is the same screen the
            // ACTION_APPLICATION_DETAILS_SETTINGS fallback below already
            // opens — so no manufacturer-specific component is needed here.
            else -> emptyList()
        }

        for (component in candidates) {
            try {
                val intent = Intent().apply {
                    setComponent(component)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // Try next candidate — OEM skins vary this across firmware versions
            } catch (_: SecurityException) {
                // Try next candidate
            }
        }

        // No known OEM screen found (or none apply) — fall back to this app's
        // details page so the user can hunt for autostart/background settings.
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            false
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
