import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/generated/app_localizations.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await NotificationService.instance.init();
  runApp(const DailyAccountApp());
}

class DailyAccountApp extends StatefulWidget {
  const DailyAccountApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    context.findAncestorStateOfType<_DailyAccountAppState>()?.setLocale(locale);
  }

  @override
  State<DailyAccountApp> createState() => _DailyAccountAppState();
}

class _DailyAccountAppState extends State<DailyAccountApp> {
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final lang = await StorageService.instance.getSetting('language', fallback: '');
    if (lang.isNotEmpty && mounted) {
      setState(() => _locale = Locale(lang));
    }
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
    StorageService.instance.setSetting('language', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Account',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(),
      locale: _locale,
      supportedLocales: S.supportedLocales,
      localizationsDelegates: S.localizationsDelegates,
      home: const SplashScreen(),
    );
  }
}
