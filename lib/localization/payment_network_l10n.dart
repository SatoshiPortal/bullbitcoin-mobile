import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart' show PaymentNetwork;

/// Maps concrete payment networks to labels from the app message catalogue.
extension PaymentNetworkL10n on PaymentNetwork {
  String toTranslated(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return switch (this) {
      PaymentNetwork.bitcoin => loc.transactionNetworkBitcoin,
      PaymentNetwork.lightning => loc.transactionNetworkLightning,
      PaymentNetwork.liquid => loc.transactionNetworkLiquid,
    };
  }
}
