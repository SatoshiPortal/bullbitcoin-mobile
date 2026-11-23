import 'package:flutter/widgets.dart';

import '../generated/l10n/swap_localizations.dart';

SwapLocalizations swapCopy(String localeName) {
  final tag = localeName.replaceAll('_', '-').toLowerCase();
  final supported = SwapLocalizations.supportedLocales;
  for (final locale in supported) {
    if (locale.toLanguageTag().toLowerCase() == tag) {
      return lookupSwapLocalizations(locale);
    }
  }
  final language = Locale(tag.split('-').first);
  return lookupSwapLocalizations(
    supported.contains(language) ? language : const Locale('en'),
  );
}

extension SwapCopyContext on BuildContext {
  SwapLocalizations get swapCopyForLocale =>
      swapCopy(Localizations.localeOf(this).toLanguageTag());
}
