import 'package:flutter/material.dart';

/// Centralised palette + type for the séance experience.
/// A warm, monochrome, editorial dark theme.
class Palette {
  Palette._();

  // Backdrop
  static const Color bg0 = Color(0xFF131211);
  static const Color bg1 = Color(0xFF1B1A18);
  static const Color glow = Color(0xFF2C2A27);

  // Surfaces
  static Color surface = Colors.white.withValues(alpha: 0.045);
  static Color surfaceStrong = Colors.white.withValues(alpha: 0.075);
  static Color border = Colors.white.withValues(alpha: 0.075);
  static Color borderStrong = Colors.white.withValues(alpha: 0.16);

  // Ink
  static const Color textHi = Color(0xFFEDEAE3);
  static Color textMid = const Color(0xFFEDEAE3).withValues(alpha: 0.58);
  static Color textLow = const Color(0xFFEDEAE3).withValues(alpha: 0.34);
}

class AppType {
  AppType._();

  static const String serif = 'Playfair';
  static const String sans = 'Inter';

  static const TextStyle logo = TextStyle(
    fontFamily: serif,
    fontStyle: FontStyle.italic,
    fontSize: 30,
    fontWeight: FontWeight.w500,
    color: Palette.textHi,
    letterSpacing: 0.2,
    height: 1.0,
  );

  static const TextStyle display = TextStyle(
    fontFamily: serif,
    fontSize: 60,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    height: 0.98,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionLabel = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Palette.textHi,
    letterSpacing: 0.1,
  );

  static final TextStyle sectionRange = TextStyle(
    fontFamily: sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    color: Palette.textLow,
    letterSpacing: 0.6,
  );

  static const TextStyle cardTitle = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Palette.textHi,
    letterSpacing: 0.1,
  );

  static final TextStyle cardBody = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: Palette.textMid,
    height: 1.38,
  );

  static final TextStyle badge = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Palette.textLow,
    letterSpacing: 1.2,
  );
}
