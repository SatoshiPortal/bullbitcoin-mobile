import 'package:bull_ui/bull_ui.dart';

import '../generated/l10n/coins_localizations.dart';

extension CoinsLocalizationContext on BuildContext {
  CoinsLocalizations get loc => CoinsLocalizations.of(this);
}
