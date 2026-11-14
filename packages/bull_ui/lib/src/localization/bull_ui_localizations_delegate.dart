import 'package:material_ui/material_ui.dart';

import '../../generated/l10n/bull_ui_localizations.dart';

/// Keeps the kit available in app locales without a kit-specific translation.
const LocalizationsDelegate<BullUiLocalizations> bullUiLocalizationsDelegate =
    _BullUiLocalizationsDelegate();

const bullUiLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  bullUiLocalizationsDelegate,
  ...GlobalMaterialLocalizations.delegates,
];

class _BullUiLocalizationsDelegate
    extends LocalizationsDelegate<BullUiLocalizations> {
  const _BullUiLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<BullUiLocalizations> load(Locale locale) =>
      BullUiLocalizations.delegate.load(
        BullUiLocalizations.delegate.isSupported(locale)
            ? locale
            : const Locale('en'),
      );

  @override
  bool shouldReload(_BullUiLocalizationsDelegate old) => false;
}
