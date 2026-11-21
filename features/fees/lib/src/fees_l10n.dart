import 'package:flutter/widgets.dart';

import '../generated/l10n/fees_localizations.dart';

FeesLocalizations feesCopy(String localeName) {
  final language = localeName.split(RegExp('[-_]')).first.toLowerCase();
  final locale = Locale(language);
  return lookupFeesLocalizations(
    FeesLocalizations.supportedLocales.contains(locale)
        ? locale
        : const Locale('en'),
  );
}
