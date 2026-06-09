import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised design system for the Daily Account app.
/// Aesthetic: warm, sacred, candle-lit. Deep espresso backgrounds with
/// gold leaf accents — evoking an illuminated manuscript / chapel ambience.
class AppTheme {
  // ── Core palette ──────────────────────────────────────────
  static const Color bg0 = Color(0xFF0D0A05); // deepest background
  static const Color bg1 = Color(0xFF1A1208); // mid background
  static const Color bg2 = Color(0xFF241A0C); // raised surface
  static const Color surface = Color(0x0FFFFFFF); // translucent card
  static const Color gold = Color(0xFFD4AF64); // primary gold
  static const Color goldDeep = Color(0xFFA07830); // deep gold
  static const Color goldSoft = Color(0xFFE8D4A0); // soft highlight
  static const Color cream = Color(0xFFF0E8D8); // body text
  static const Color sand = Color(0xFFA09070); // muted text
  static const Color clay = Color(0xFF7A6A4A); // faint text
  static const Color green = Color(0xFF6FBF73); // success / complete
  static const Color rust = Color(0xFFC97B5A); // warning / error

  // ── Gradients ─────────────────────────────────────────────
  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bg0, bg1, bg0],
    stops: [0.0, 0.5, 1.0],
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

  // ── ThemeData ─────────────────────────────────────────────
  static ThemeData themeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg0,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: goldDeep,
        surface: bg1,
      ),
      textTheme: GoogleFonts.loraTextTheme(ThemeData.dark().textTheme),
    );
  }
}
