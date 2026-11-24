import '../swap_l10n.dart';

import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart' show PaymentNetwork;

/// Maps concrete payment networks to labels from the swap message catalogue.
extension PaymentNetworkL10n on PaymentNetwork {
  String toTranslated(BuildContext context) {
    final loc = context.swapCopyForLocale;
    return switch (this) {
      PaymentNetwork.bitcoin => loc.transactionNetworkBitcoin,
      PaymentNetwork.lightning => loc.transactionNetworkLightning,
      PaymentNetwork.liquid => loc.transactionNetworkLiquid,
    };
  }
}
