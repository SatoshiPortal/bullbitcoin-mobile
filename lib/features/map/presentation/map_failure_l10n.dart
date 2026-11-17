import 'package:bull_map/bull_map.dart';
import 'package:flutter/widgets.dart';

import 'package:bb_mobile/core/utils/build_context_x.dart';

extension BullMapFailureL10n on BullMapFailure {
  String toTranslated(BuildContext context) => switch (this) {
    BullMapNetworkFailure() => context.loc.merchantMapNetworkFailure,
    BullMapUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
