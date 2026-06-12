import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/generated/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/lock_screen.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/timer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotificationService.instance.init();
  await TimerService.instance.init();
  runApp(const DailyAccountApp());
}

class DailyAccountApp extends StatefulWidget {
  const DailyAccountApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setLocale(locale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setThemeMode(mode);
  }

  @override
  State<DailyAccountApp> createState() => _DailyAccountAppState();
}

class _DailyAccountAppState extends State<DailyAccountApp> {
  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final s = StorageService.instance;
    final lang = await s.getSetting('language', fallback: '');
    final theme = await s.getSetting('themeMode', fallback: 'dark');
    if (mounted) {
      setState(() {
        if (lang.isNotEmpty) _locale = Locale(lang);
        _themeMode = theme == 'light' ? ThemeMode.light : ThemeMode.dark;
      });
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    StorageService.instance.setSetting('language', locale.languageCode);
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
      home: const LockScreen(child: SplashScreen()),
    );
  }
}
