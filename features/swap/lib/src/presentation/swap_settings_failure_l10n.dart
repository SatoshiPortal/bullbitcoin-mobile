import 'package:flutter/widgets.dart';
import 'package:swaps/swaps.dart';

import '../swap_l10n.dart';

extension SwapSettingsFailureL10n on SwapsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    SwapsBusyFailure() => context.swapCopyForLocale.swapServerBusyError,
    SwapsUnsupportedNetworkFailure() =>
      context.swapCopyForLocale.networkFeatureUnavailable,
    _ => context.swapCopyForLocale.oopsSomethingWentWrong,
  };
}
