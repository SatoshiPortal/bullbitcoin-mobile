import 'package:bb_mobile/core/primitives/payment_network.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

/// Kept in its own file so [PaymentNetwork] itself stays Flutter-free.
extension PaymentNetworkL10n on PaymentNetwork {
  String toTranslated(BuildContext context) => switch (this) {
    PaymentNetwork.bitcoin => context.loc.transactionNetworkBitcoin,
    PaymentNetwork.lightning => context.loc.transactionNetworkLightning,
    PaymentNetwork.liquid => context.loc.transactionNetworkLiquid,
  };
}
