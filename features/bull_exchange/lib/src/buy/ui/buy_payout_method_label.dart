import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:secrets/secrets.dart';
import 'package:primitives/primitives.dart' show LiquidNetwork;

extension BuyWalletLabel on WalletRegistration {
  String displayLabel(BuildContext context) {
    final name = label;
    if (!isDefault) {
      return name ??
          buyPayoutMethodLabel(context, isLiquid: network is LiquidNetwork);
    }
    return network is LiquidNetwork
        ? context.loc.globalDefaultLiquidWalletLabel
        : context.loc.globalDefaultBitcoinWalletLabel;
  }
}

/// The network a buy pays out over, worded for the user. Shared by the wallet
/// dropdown and the confirmation screen so that the two cannot drift.
String buyPayoutMethodLabel(BuildContext context, {required bool isLiquid}) {
  return isLiquid
      ? context.loc.buyPayoutMethodLiquid
      : context.loc.buyPayoutMethodBitcoin;
}
