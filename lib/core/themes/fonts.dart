import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static const _textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 46, fontWeight: .w500),
    displayMedium: TextStyle(fontSize: 43, fontWeight: .w500),
    displaySmall: TextStyle(
      fontSize: 28,
      fontWeight: .w500,
      // height: 34,
    ),
    headlineLarge: TextStyle(
      fontSize: 16,
      fontWeight: .w700,
      // height: 24,
    ),
    headlineMedium: TextStyle(
      fontSize: 16,
      fontWeight: .w500,
      // height: 24,
    ),
    headlineSmall: TextStyle(
      fontSize: 16,
      // height: 24,
    ),
    // titleLarge: TextStyle(),
    // titleMedium: TextStyle(),
    // titleSmall: TextStyle(),
    bodyLarge: TextStyle(
      fontSize: 14,
      // height: 18,
      fontWeight: .w500,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      // height: 18,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      // height: 18,
    ),
    labelLarge: TextStyle(
      fontSize: 12,
      // height: 18,
      fontWeight: .w500,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      // height: 18,
    ),
    labelSmall: TextStyle(fontSize: 10),
  );

  static ({String fontFamily, TextTheme textTheme}) textTheme = (
    fontFamily: 'Golos',
    textTheme: GoogleFonts.golosTextTextTheme(_textTheme),
  );

  static ({String fontFamily, TextStyle textStyle}) textTitleTheme = (
    fontFamily: 'Bebas Neue',
    textStyle: GoogleFonts.bebasNeue(),
  );
}
