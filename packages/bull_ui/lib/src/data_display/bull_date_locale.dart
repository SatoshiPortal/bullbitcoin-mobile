import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The intl locale to format absolute dates in the app's language.
///
/// intl keys date data by language, not script: Hinglish (`hi_Latn`) would
/// fall back to Hindi's Devanagari month names. A locale with a script
/// therefore reads in English, as relative dates already do.
String bullDateLocale(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.scriptCode != null) return 'en';
  return Intl.canonicalizedLocale(locale.toString());
}
