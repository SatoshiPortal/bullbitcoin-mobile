import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:material_ui/material_ui.dart';

export 'package:bb_mobile/generated/l10n/localization.dart'
    show AppLocalizations, lookupAppLocalizations;

// Flutter's generated delegate list still names the SDK design libraries.
// Keep the app on the standalone delegates across automatic regeneration.
const appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];
