import 'package:btc_map/src/map_types.dart';
import 'package:flutter/widgets.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';

extension BullMapFailureL10n on BullMapFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BullMapNetworkFailure() => context.btcMapLoc.merchantMapNetworkFailure,
    BullMapUnexpectedFailure() => context.btcMapLoc.oopsSomethingWentWrong,
  };
}
