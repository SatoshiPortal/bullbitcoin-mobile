import 'package:flutter/widgets.dart';

import '../generated/l10n/fees_localizations.dart';

FeesLocalizations feesCopy(String localeName) {
  final tag = localeName.replaceAll('_', '-').toLowerCase();
  final supported = FeesLocalizations.supportedLocales;
  for (final locale in supported) {
    if (locale.toLanguageTag().toLowerCase() == tag) {
      return lookupFeesLocalizations(locale);
    }
  }
  final language = Locale(tag.split('-').first);
  return lookupFeesLocalizations(
    supported.contains(language) ? language : const Locale('en'),
  );
}
