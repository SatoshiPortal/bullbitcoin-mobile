import 'package:flutter/widgets.dart';
import 'package:silent/generated/l10n/silent_localizations.dart';

extension SilentLocalizationsX on BuildContext {
  SilentLocalizations get silentLoc => SilentLocalizations.of(this);
}

SilentLocalizations silentCopy(String localeName) {
  final tag = localeName.replaceAll('_', '-').toLowerCase();
  final supported = SilentLocalizations.supportedLocales;
  for (final locale in supported) {
    if (locale.toLanguageTag().toLowerCase() == tag) {
      return lookupSilentLocalizations(locale);
    }
  }
  final language = Locale(tag.split('-').first);
  return lookupSilentLocalizations(
    supported.contains(language) ? language : const Locale('en'),
  );
}
