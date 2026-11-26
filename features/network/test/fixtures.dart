import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:network/generated/l10n/network_localizations.dart';

const networkTestLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  NetworkLocalizations.delegate,
  ...bullUiLocalizationsDelegates,
];

ThemeData networkTestTheme() => ThemeData(
  brightness: Brightness.light,
  extensions: bullUiExtensions(
    colors: testBullTheme,
    brightness: Brightness.light,
  ),
);
