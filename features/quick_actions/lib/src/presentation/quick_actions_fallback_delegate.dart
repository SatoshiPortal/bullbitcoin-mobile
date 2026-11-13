import 'package:bull_ui/bull_ui.dart' show Locale, LocalizationsDelegate;

import '../../generated/l10n/quick_actions_localizations.dart';

/// Uses French when available and English for other application locales.
final class QuickActionsFallbackDelegate
    extends LocalizationsDelegate<QuickActionsLocalizations> {
  const QuickActionsFallbackDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<QuickActionsLocalizations> load(Locale locale) =>
      QuickActionsLocalizations.delegate.load(
        Locale(locale.languageCode == 'fr' ? 'fr' : 'en'),
      );

  @override
  bool shouldReload(QuickActionsFallbackDelegate old) => false;
}
