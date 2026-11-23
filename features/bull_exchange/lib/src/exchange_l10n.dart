import 'package:flutter/widgets.dart';

import '../generated/l10n/exchange_localizations.dart';

extension ExchangeL10n on BuildContext {
  ExchangeLocalizations get loc => ExchangeLocalizations.of(this);
}
