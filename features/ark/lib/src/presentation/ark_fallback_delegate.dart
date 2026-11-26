import 'package:bull_ui/bull_ui.dart' show Locale, LocalizationsDelegate;

import '../../generated/l10n/ark_localizations.dart';

/// Package catalogues currently provide French and English. Other application
/// locales use English until translations are supplied through tools/arb.dart.
final class ArkFallbackDelegate
    extends LocalizationsDelegate<ArkLocalizations> {
  const ArkFallbackDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<ArkLocalizations> load(Locale locale) => ArkLocalizations.delegate
      .load(Locale(locale.languageCode == 'fr' ? 'fr' : 'en'));
  @override
  bool shouldReload(ArkFallbackDelegate old) => false;
}
