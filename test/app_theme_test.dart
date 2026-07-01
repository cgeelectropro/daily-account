import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_account/theme/app_theme.dart';

/// Prevents GoogleFonts from making real HTTP requests during tests.
class _NoHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) => false;
    return client;
  }
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = _NoHttpOverrides();
  });

  // ---------------------------------------------------------------------------
  // Color constants
  // ---------------------------------------------------------------------------
  group('Dark palette color constants', () {
    test('bg0 has expected hex value', () {
      expect(AppTheme.bg0, const Color(0xFF0D0A05));
    });

    test('bg1 has expected hex value', () {
      expect(AppTheme.bg1, const Color(0xFF1A1208));
    });

    test('bg2 has expected hex value', () {
      expect(AppTheme.bg2, const Color(0xFF241A0C));
    });

    test('gold has expected hex value', () {
      expect(AppTheme.gold, const Color(0xFFD4AF64));
    });

    test('goldDeep has expected hex value', () {
      expect(AppTheme.goldDeep, const Color(0xFFA07830));
    });

    test('goldSoft has expected hex value', () {
      expect(AppTheme.goldSoft, const Color(0xFFE8D4A0));
    });

    test('cream has expected hex value', () {
      expect(AppTheme.cream, const Color(0xFFF0E8D8));
    });

    test('sand has expected hex value', () {
      expect(AppTheme.sand, const Color(0xFFA09070));
    });

    test('clay has expected hex value', () {
      expect(AppTheme.clay, const Color(0xFF7A6A4A));
    });

    test('green has expected hex value', () {
      expect(AppTheme.green, const Color(0xFF6FBF73));
    });

    test('rust has expected hex value', () {
      expect(AppTheme.rust, const Color(0xFFC97B5A));
    });

    test('bg0 is darker than bg1 (lower combined RGB)', () {
      const bg0 = AppTheme.bg0;
      const bg1 = AppTheme.bg1;
      final bg0Sum = bg0.r + bg0.g + bg0.b;
      final bg1Sum = bg1.r + bg1.g + bg1.b;
      expect(bg0Sum, lessThan(bg1Sum));
    });

    test('bg1 is darker than bg2 (lower combined RGB)', () {
      const bg1 = AppTheme.bg1;
      const bg2 = AppTheme.bg2;
      final bg1Sum = bg1.r + bg1.g + bg1.b;
      final bg2Sum = bg2.r + bg2.g + bg2.b;
      expect(bg1Sum, lessThan(bg2Sum));
    });

    test('green and rust are distinct colors', () {
      expect(AppTheme.green, isNot(equals(AppTheme.rust)));
    });
  });

  group('Light palette color constants', () {
    test('lightBg0 has expected hex value', () {
      expect(AppTheme.lightBg0, const Color(0xFFFFFDF8));
    });

    test('lightBg1 has expected hex value', () {
      expect(AppTheme.lightBg1, const Color(0xFFF5F0E6));
    });

    test('lightBg2 has expected hex value', () {
      expect(AppTheme.lightBg2, const Color(0xFFEDE6D6));
    });

    test('lightText has expected hex value', () {
      expect(AppTheme.lightText, const Color(0xFF1A1207));
    });

    test('lightMuted has expected hex value', () {
      expect(AppTheme.lightMuted, const Color(0xFF5C4E38));
    });

    test('lightFaint has expected hex value', () {
      expect(AppTheme.lightFaint, const Color(0xFF8A7C64));
    });

    test('lightGold has expected hex value', () {
      expect(AppTheme.lightGold, const Color(0xFF9A7B1C));
    });
  });

  // ---------------------------------------------------------------------------
  // Gradients
  // ---------------------------------------------------------------------------
  group('Gradients', () {
    test('bgGradient has 3 colors', () {
      expect(AppTheme.bgGradient.colors, hasLength(3));
    });

    test('bgGradient has 3 stops', () {
      expect(AppTheme.bgGradient.stops, hasLength(3));
    });

    test('bgGradient stops are [0.0, 0.5, 1.0]', () {
      expect(AppTheme.bgGradient.stops, equals([0.0, 0.5, 1.0]));
    });

    test('bgGradient colors are bg0, bg1, bg0', () {
      expect(AppTheme.bgGradient.colors[0], AppTheme.bg0);
      expect(AppTheme.bgGradient.colors[1], AppTheme.bg1);
      expect(AppTheme.bgGradient.colors[2], AppTheme.bg0);
    });

    test('lightBgGradient has 2 colors', () {
      expect(AppTheme.lightBgGradient.colors, hasLength(2));
    });

    test('lightBgGradient both colors are lightBg0', () {
      expect(AppTheme.lightBgGradient.colors[0], AppTheme.lightBg0);
      expect(AppTheme.lightBgGradient.colors[1], AppTheme.lightBg0);
    });

    test('goldGradient has 2 colors', () {
      expect(AppTheme.goldGradient.colors, hasLength(2));
    });

    test('goldGradient colors are gold and goldDeep', () {
      expect(AppTheme.goldGradient.colors[0], AppTheme.gold);
      expect(AppTheme.goldGradient.colors[1], AppTheme.goldDeep);
    });
  });

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------
  group('Typography — display()', () {
    test('display(18) returns TextStyle with fontSize 18', () {
      final style = AppTheme.display(18);
      expect(style.fontSize, 18.0);
    });

    test('display(18) defaults to cream color', () {
      final style = AppTheme.display(18);
      expect(style.color, AppTheme.cream);
    });

    test('display(18) defaults to FontWeight.w700', () {
      final style = AppTheme.display(18);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('display(18, color: Colors.red) overrides color to red', () {
      final style = AppTheme.display(18, color: Colors.red);
      expect(style.color, Colors.red);
    });

    test('display(18, weight: FontWeight.w400) overrides weight', () {
      final style = AppTheme.display(18, weight: FontWeight.w400);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('display() applies letterSpacing 0.5', () {
      final style = AppTheme.display(18);
      expect(style.letterSpacing, 0.5);
    });
  });

  group('Typography — serif()', () {
    test('serif(14) returns TextStyle with fontSize 14', () {
      final style = AppTheme.serif(14);
      expect(style.fontSize, 14.0);
    });

    test('serif(14) defaults to cream color', () {
      final style = AppTheme.serif(14);
      expect(style.color, AppTheme.cream);
    });

    test('serif(14) defaults to FontWeight.w400', () {
      final style = AppTheme.serif(14);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('serif(14) has height 1.5', () {
      final style = AppTheme.serif(14);
      expect(style.height, 1.5);
    });

    test('serif(14) defaults to FontStyle.normal', () {
      final style = AppTheme.serif(14);
      expect(style.fontStyle, FontStyle.normal);
    });

    test('serif(14, color: Colors.blue) overrides color', () {
      final style = AppTheme.serif(14, color: Colors.blue);
      expect(style.color, Colors.blue);
    });

    test('serif(14, weight: FontWeight.w700) overrides weight', () {
      final style = AppTheme.serif(14, weight: FontWeight.w700);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('serif(14, style: FontStyle.italic) overrides fontStyle', () {
      final style = AppTheme.serif(14, style: FontStyle.italic);
      expect(style.fontStyle, FontStyle.italic);
    });
  });

  group('Typography — label()', () {
    test('label(12) returns TextStyle with fontSize 12', () {
      final style = AppTheme.label(12);
      expect(style.fontSize, 12.0);
    });

    test('label(12) defaults to sand color', () {
      final style = AppTheme.label(12);
      expect(style.color, AppTheme.sand);
    });

    test('label(12) has letterSpacing 2.0', () {
      final style = AppTheme.label(12);
      expect(style.letterSpacing, 2.0);
    });

    test('label(12) uses FontWeight.w600', () {
      final style = AppTheme.label(12);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('label(12, color: Colors.white) overrides color', () {
      final style = AppTheme.label(12, color: Colors.white);
      expect(style.color, Colors.white);
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeData factories
  // ---------------------------------------------------------------------------
  group('darkTheme()', () {
    late ThemeData theme;

    setUpAll(() {
      theme = AppTheme.darkTheme();
    });

    test('brightness is dark', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('scaffoldBackgroundColor equals bg0', () {
      expect(theme.scaffoldBackgroundColor, AppTheme.bg0);
    });

    test('colorScheme.primary equals gold', () {
      expect(theme.colorScheme.primary, AppTheme.gold);
    });

    test('colorScheme.secondary equals goldDeep', () {
      expect(theme.colorScheme.secondary, AppTheme.goldDeep);
    });

    test('useMaterial3 is true', () {
      expect(theme.useMaterial3, isTrue);
    });
  });

  group('lightTheme()', () {
    late ThemeData theme;

    setUpAll(() {
      theme = AppTheme.lightTheme();
    });

    test('brightness is light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('scaffoldBackgroundColor equals lightBg0', () {
      expect(theme.scaffoldBackgroundColor, AppTheme.lightBg0);
    });

    test('colorScheme.primary equals lightGold', () {
      expect(theme.colorScheme.primary, AppTheme.lightGold);
    });

    test('colorScheme.secondary equals goldDeep', () {
      expect(theme.colorScheme.secondary, AppTheme.goldDeep);
    });

    test('useMaterial3 is true', () {
      expect(theme.useMaterial3, isTrue);
    });
  });
}
