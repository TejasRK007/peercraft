import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color primaryPurple = Color(0xFF7C5CFC);
  static const Color softPurple = Color(0xFFB39DDB);
  static const Color lightLavender = Color(0xFFEDE7FF);
  static const Color backgroundWhite = Color(0xFFFAF9FF);
  static const Color deepPurple = Color(0xFF2D1B69);
  static const Color bluePurple = Color(0xFF5A4FCF);
  static const Color accentCoral = Color(0xFFFF7F7F);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF8A8AA8);
  static const Color surfaceWhite = Color(0xFFFFFFFF);

  // ── Gradients ────────────────────────────────────────────────────────────
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE8DEFF), // soft lavender
      Color(0xFFF5F0FF), // near-white lavender
      Color(0xFFFAF9FF), // almost white
    ],
    stops: [0.0, 0.45, 1.0],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF2D1B69), Color(0xFF4A2FA3)],
  );

  // ── TextStyles ───────────────────────────────────────────────────────────
  static const TextStyle headlineStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: textDark,
    height: 1.15,
    letterSpacing: -0.5,
  );

  static const TextStyle subtitleStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.6,
    letterSpacing: 0.1,
  );

  static const TextStyle buttonTextStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  static const TextStyle labelStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyStyle = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textDark,
  );

  static const TextStyle headingSmall = TextStyle(
    fontFamily: 'Outfit',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: textDark,
    letterSpacing: -0.3,
  );

  // ── Theme Data ───────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      textTheme: GoogleFonts.outfitTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryPurple,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundWhite,
    );
  }
}
