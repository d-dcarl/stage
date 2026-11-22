import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StageColors {
  static const bg = Color(0xFFF6F5F2);
  static const ink = Color(0xFF16161A);
  static const muted = Color(0xFF5E5E66);
  static const line = Color(0xFFDAD8D2);
  static const accent = Color(0xFF5B3DF5);
  static const accentLight = Color(0xFF8E7BFF);
  static const tint = Color(0xFFECE8FF);
  static const dark = Color(0xFF16161A);
  static const dark2 = Color(0xFF232329);
  static const darkLine = Color(0xFF44444C);
}

ThemeData stageTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: StageColors.accent, surface: StageColors.bg),
    scaffoldBackgroundColor: StageColors.bg,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: StageColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: const StadiumBorder(),
      ),
    ),
  );
}

TextStyle display(double size, {Color? color}) =>
    GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: FontWeight.w700, height: 1.15, color: color);
