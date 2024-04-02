import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class _Colours {
  static const blue = Color(0xFF217FB4);
  static const red = Color(0xFFC50909);
  static const gray = Color(0xFF666666);
  static const black = Colors.black;
  static const darkGray = Color(0xFF333333);
  static const white = Colors.white;
}

class NewColours {
  static const offWhite = Color(0xFFFBFBFB);
  static const lightGray = Color(0xFFC4C4C4);
}

class Themes {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(),
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _Colours.red,
      onPrimary: _Colours.white,
      secondary: _Colours.blue,
      onSecondary: _Colours.white,
      surface: _Colours.gray,
      onSurface: _Colours.white,
      background: _Colours.white,
      onBackground: _Colours.black,
      error: _Colours.red,
      onError: _Colours.white,
    ),
    scaffoldBackgroundColor: _Colours.white,
    visualDensity: VisualDensity.comfortable,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      backgroundColor: _Colours.white,
      elevation: 1,
      shadowColor: _Colours.gray,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: _Colours.red,
      onPrimary: _Colours.white,
      secondary: _Colours.blue,
      onSecondary: _Colours.white,
      surface: _Colours.gray,
      onSurface: _Colours.white,
      background: _Colours.black,
      onBackground: _Colours.white,
      error: _Colours.red,
      onError: _Colours.white,
    ),
    scaffoldBackgroundColor: _Colours.black,
    visualDensity: VisualDensity.compact,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: _Colours.black,
      elevation: 2,
      shadowColor: NewColours.offWhite,
    ),
  );

  static ThemeData dimTheme = ThemeData(
    useMaterial3: true,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: _Colours.red,
      onPrimary: _Colours.white,
      secondary: _Colours.blue,
      onSecondary: _Colours.white,
      surface: _Colours.gray,
      onSurface: _Colours.white,
      background: _Colours.darkGray,
      onBackground: _Colours.white,
      error: _Colours.red,
      onError: _Colours.white,
    ),
    scaffoldBackgroundColor: _Colours.darkGray,
    visualDensity: VisualDensity.comfortable,
    // brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle.light,
      backgroundColor: _Colours.darkGray,
      elevation: 2,
      shadowColor: NewColours.offWhite,
    ),
  );
}

extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get font => theme.textTheme;
  ColorScheme get colour => theme.colorScheme;
}

(TextTheme, String) buildFonts(bool isTest) {
  final family = GoogleFonts.inter().fontFamily!;
  final theme = GoogleFonts.interTextTheme();
  // final f2 = GoogleFonts.bebasNeue().fontFamily!;

  if (isTest) {
    return (theme, family);
  }

  return (theme, family);
}
