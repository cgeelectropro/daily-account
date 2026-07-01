import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/generated/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/lock_screen.dart';
import 'screens/splash_screen.dart';
import 'services/backup_service.dart';
import 'services/background_timer_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/timer_service.dart';
import 'widgets/timer_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('[main] NotificationService init failed: $e');
  }
  try { await BackgroundTimerService.instance.init(); } catch (_) {}
  try { await TimerService.instance.init(); } catch (_) {}
  // Silent auto-backup on every app start (skips if < 6 hours since last)
  BackupService.instance.autoBackup();
  // Restore Google sign-in session (fire-and-forget)
  CloudSyncService.instance.silentSignIn();
  runApp(const DailyAccountApp());
}

/// Entry point for the floating timer overlay (runs in a separate isolate).
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TimerOverlay(),
    ),
  );
}

class DailyAccountApp extends StatefulWidget {
  const DailyAccountApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setLocale(locale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setThemeMode(mode);
  }

  static void setTextScale(BuildContext context, double scale) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setTextScale(scale);
  }

  static double getTextScale(BuildContext context) {
    return context.findAncestorStateOfType<_DailyAccountAppState>()?._textScale ?? 1.0;
  }

  @override
  State<DailyAccountApp> createState() => _DailyAccountAppState();
}

class _DailyAccountAppState extends State<DailyAccountApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.dark;
  double _textScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final s = StorageService.instance;
    final lang = await s.getSetting('language', fallback: '');
    final theme = await s.getSetting('themeMode', fallback: 'dark');
    final scale = await s.getSetting('textScale', fallback: '1.0');
    if (mounted) {
      setState(() {
        if (lang.isNotEmpty) _locale = Locale(lang);
        _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
        _textScale = double.tryParse(scale) ?? 1.0;
      });
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    StorageService.instance.setSetting('language', locale.languageCode);
  }

  void setTextScale(double scale) {
    setState(() => _textScale = scale);
    StorageService.instance.setSetting('textScale', scale.toStringAsFixed(1));
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
    StorageService.instance.setSetting('themeMode', mode == ThemeMode.light ? 'light' : 'dark');
    // Update system chrome style
    SystemChrome.setSystemUIOverlayStyle(
      mode == ThemeMode.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Account',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      locale: _locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: S.localizationsDelegates,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(_textScale),
          ),
          child: child!,
        );
      },
      home: const LockScreen(child: SplashScreen()),
    );
  }
}
