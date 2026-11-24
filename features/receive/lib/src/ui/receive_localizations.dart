import 'package:flutter/widgets.dart';
import 'package:primitives/primitives.dart';

import '../../generated/l10n/receive_localizations.dart';
import '../domain/receive_wallet.dart';

extension ReceiveLocalizationContext on BuildContext {
  ReceiveLocalizations get loc => ReceiveLocalizations.of(this);
}

extension ReceiveWalletL10n on ReceiveWallet {
  String displayLabel(BuildContext context) => isDefault
      ? isBitcoin
            ? context.loc.globalDefaultBitcoinWalletLabel
            : context.loc.globalDefaultLiquidWalletLabel
      : label ??
            (network.env == NetworkEnv.regtest && id.endsWith(':regtest')
                ? id.substring(0, id.length - ':regtest'.length)
                : id);
}

extension ReceivePaymentNetworkL10n on PaymentNetwork {
  String toTranslated(BuildContext context) => switch (this) {
    PaymentNetwork.bitcoin => context.loc.transactionNetworkBitcoin,
    PaymentNetwork.lightning => context.loc.transactionNetworkLightning,
    PaymentNetwork.liquid => context.loc.transactionNetworkLiquid,
  };
}
