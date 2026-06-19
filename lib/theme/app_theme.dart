import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design system for the Daily Account app.
/// Supports both dark (espresso) and light (parchment) modes.
class AppTheme {
  // ── Dark palette (espresso + gold-leaf) ───────────────────
  static const Color bg0 = Color(0xFF0D0A05); // deepest background
  static const Color bg1 = Color(0xFF1A1208); // mid background
  static const Color bg2 = Color(0xFF241A0C); // raised surface
  static const Color gold = Color(0xFFD4AF64); // primary gold
  static const Color goldDeep = Color(0xFFA07830); // deep gold
  static const Color goldSoft = Color(0xFFE8D4A0); // soft highlight
  static const Color cream = Color(0xFFF0E8D8); // body text (dark mode)
  static const Color sand = Color(0xFFA09070); // muted text
  static const Color clay = Color(0xFF7A6A4A); // faint text
  static const Color green = Color(0xFF6FBF73); // success / complete
  static const Color rust = Color(0xFFC97B5A); // warning / error

  // ── Light palette (clean warm white + rich gold) ───────────
  static const Color lightBg0 = Color(0xFFFFFDF8); // clean warm white
  static const Color lightBg1 = Color(0xFFF5F0E6); // subtle warm tint for nav
  static const Color lightBg2 = Color(0xFFEDE6D6); // raised cards/surfaces
  static const Color lightText = Color(0xFF1A1207); // near-black for max readability
  static const Color lightMuted = Color(0xFF5C4E38); // readable secondary text
  static const Color lightFaint = Color(0xFF8A7C64); // tertiary / hints
  static const Color lightGold = Color(0xFF9A7B1C); // rich deep gold for contrast

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg0, bg1, bg0],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient lightBgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [lightBg0, lightBg0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold, goldDeep],
  );

  // ── Typography ────────────────────────────────────────────
  static TextStyle display(double size, {Color? color, FontWeight? weight}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        color: color ?? cream,
        fontWeight: weight ?? FontWeight.w700,
        letterSpacing: 0.5,
      );

  static TextStyle serif(double size, {Color? color, FontWeight? weight, FontStyle? style}) =>
      GoogleFonts.lora(
        fontSize: size,
        color: color ?? cream,
        fontWeight: weight ?? FontWeight.w400,
        fontStyle: style ?? FontStyle.normal,
        height: 1.5,
      );

  static TextStyle label(double size, {Color? color}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        color: color ?? sand,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
      );

  // ── Brightness-aware helpers ──────────────────────────────
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textColor(BuildContext context) =>
      isDark(context) ? cream : lightText;

  static Color mutedColor(BuildContext context) =>
      isDark(context) ? sand : lightMuted;

  static Color faintColor(BuildContext context) =>
      isDark(context) ? clay : lightFaint;

  static Color surfaceColor(BuildContext context) =>
      isDark(context) ? bg2 : lightBg2;

  static Color bgColor(BuildContext context) =>
      isDark(context) ? bg0 : lightBg0;

  static Color accentGold(BuildContext context) =>
      isDark(context) ? gold : lightGold;

  static LinearGradient backgroundGradient(BuildContext context) =>
      isDark(context) ? bgGradient : lightBgGradient;

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg0,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldDeep,
        surface: bg1,
      ),
      textTheme: GoogleFonts.loraTextTheme(ThemeData.dark().textTheme),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg0,
      colorScheme: const ColorScheme.light(
        primary: lightGold,
        secondary: goldDeep,
        surface: lightBg1,
      ),
      textTheme: GoogleFonts.loraTextTheme(ThemeData.light().textTheme),
    );
  }
}
