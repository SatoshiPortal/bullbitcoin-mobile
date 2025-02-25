import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ThemeData
  static ThemeData themeData(
    ColorScheme colorScheme,
    Color focusColor, {
    TextTheme? textTheme,
    FilledButtonThemeData? filledButtonTheme,
    TextButtonThemeData? textButtonTheme,
    CardTheme? cardTheme,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      canvasColor: colorScheme.surface,
      scaffoldBackgroundColor: colorScheme.surface,
      highlightColor: Colors.transparent,
      focusColor: focusColor,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: textTheme ?? GoogleFonts.interTextTheme(),
      filledButtonTheme: filledButtonTheme,
      textButtonTheme: textButtonTheme,
      cardTheme: cardTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: const Color(0xFF75808A),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: navigationBarTextTheme.labelSmall,
        unselectedLabelStyle: navigationBarTextTheme.labelSmall,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  // Themes
  static ThemeData lightThemeData = themeData(
    lightColorScheme,
    _lightFocusColor,
    textTheme: lightTextTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(78),
          ),
        ),
        textStyle: WidgetStateProperty.all(lightTextTheme.titleSmall),
        minimumSize: WidgetStateProperty.all(const Size(364, 60)),
        //maximumSize: WidgetStateProperty.all(const Size(364, 60)),
      ),
    ),
    cardTheme: CardTheme(
      color: lightColorScheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
  );

  static ThemeData onboardingThemeData = themeData(
    onboardingColorScheme,
    _lightFocusColor,
    textTheme: onboardingTextTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shadowColor: WidgetStateProperty.all(Colors.black.withOpacity(0.25)),
        elevation: WidgetStateProperty.all(4.87),
        minimumSize: WidgetStateProperty.all(const Size(344, 54)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        textStyle: WidgetStateProperty.all(onboardingTextTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        textStyle: WidgetStateProperty.all(onboardingTextTheme.bodySmall
            ?.copyWith(fontWeight: FontWeight.w600)),
      ),
    ),
  );

  // Color schemes
  static final Color _lightFocusColor = Colors.black.withOpacity(0.12);

  static const ColorScheme lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5046E5),
    onPrimary: Colors.white,
    secondary: Color(0xFFF2F2F2),
    onSecondary: Colors.black,
    tertiary: Color(0xFF147E03),
    error: Colors.red,
    onError: Colors.white,
    surface: Color(0xFFF4F6FA),
    onSurface: Colors.black,
    primaryContainer: Colors.white,
    onPrimaryContainer: Colors.black,
    onSurfaceVariant: Color(0xFF636363),
    secondaryContainer: Color(0xFF494949),
    onSecondaryContainer: Colors.white,
  );

  static const ColorScheme onboardingColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF1849D6),
    onPrimary: Colors.white,
    secondary: Color(0xFFF3F3F3),
    onSecondary: Color(0xFF5046E5),
    tertiary: Color(0xFF9304D7),
    onTertiary: Colors.white,
    error: Color(0xFFD61818),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1F1F1F),
    onSurfaceVariant: Color(0xFF1849D6),
    surfaceContainerHighest: Color(0x4FFFFFFF),
  );

  // Text themes
  static final TextTheme lightTextTheme = GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.inter(
      fontSize: 60,
      fontWeight: FontWeight.w700,
      height: 72.61 / 60,
    ),
    displayMedium: GoogleFonts.inter(
      fontSize: 46,
      height: 55.67 / 46,
      fontWeight: FontWeight.w700,
    ),
    displaySmall: GoogleFonts.inter(
      fontSize: 32,
      height: 38.73 / 32,
      fontWeight: FontWeight.w700,
    ),
    headlineLarge: GoogleFonts.inter(
      fontSize: 31,
      height: 37.52 / 31,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.inter(
      fontSize: 26,
      height: 31.74 / 26,
      fontWeight: FontWeight.w700,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 22,
      height: 26.63 / 22,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: GoogleFonts.inter(
      fontSize: 18,
      height: 21.78 / 18,
      fontWeight: FontWeight.w400,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 17,
      height: 25.24 / 17,
      fontWeight: FontWeight.w500,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 17,
      height: 20.57 / 17,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      height: 19.36 / 16,
      fontWeight: FontWeight.w400,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 15,
      height: 18.15 / 15,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 14,
      height: 18.2 / 14,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      height: 16.94 / 14,
      fontWeight: FontWeight.w400,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 13,
      height: 15.73 / 13,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 12,
      height: 14.52 / 12,
      fontWeight: FontWeight.w600,
    ),
  );

  static final TextTheme navigationBarTextTheme =
      GoogleFonts.robotoTextTheme().copyWith(
    labelSmall: GoogleFonts.roboto(
      fontSize: 12,
      height: 14 / 12,
      fontWeight: FontWeight.w500,
    ),
  );

  static final TextTheme onboardingTextTheme =
      GoogleFonts.interTextTheme().copyWith(
    headlineMedium: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 28 / 20,
    ),
    headlineSmall: GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 26 / 18,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 22 / 16,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    ),
  );
}
