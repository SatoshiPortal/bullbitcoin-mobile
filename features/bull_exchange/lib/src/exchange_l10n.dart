import 'package:bull_ui/bull_ui.dart' show BullTheme, BullThemeX;
import 'package:flutter/widgets.dart';

import '../generated/l10n/exchange_localizations.dart';

extension ExchangeL10n on BuildContext {
  ExchangeLocalizations get loc => ExchangeLocalizations.of(this);
}

extension ExchangeTheme on BuildContext {
  BullTheme get appColors => bull;
}
