import 'package:bull_ui/bull_ui.dart' show BuildContext;

import '../../generated/l10n/btc_map_localizations.dart';

extension MapLocalizationsX on BuildContext {
  BtcMapLocalizations get btcMapLoc => BtcMapLocalizations.of(this);
}
