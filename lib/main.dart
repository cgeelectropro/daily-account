import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initialise notifications early so reminders can fire.
  await NotificationService.instance.init();
  runApp(const DailyAccountApp());
}

class DailyAccountApp extends StatelessWidget {
  const DailyAccountApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Account',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(),
      home: const SplashScreen(),
    );
  }
}
