import 'package:send/generated/l10n/send_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart' show PaymentNetwork;

/// Maps concrete payment networks to labels from the app message catalogue.
extension PaymentNetworkL10n on PaymentNetwork {
  String toTranslated(BuildContext context) {
    final loc = SendLocalizations.of(context);
    return switch (this) {
      PaymentNetwork.bitcoin => loc.transactionNetworkBitcoin,
      PaymentNetwork.lightning => loc.transactionNetworkLightning,
      PaymentNetwork.liquid => loc.transactionNetworkLiquid,
    };
  }
}
