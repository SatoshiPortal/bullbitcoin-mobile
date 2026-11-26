import 'package:bull_exchange/src/buy/domain/buy_flow.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

extension BuyWalletLabel on BuyPayoutWallet {
  String displayLabel(BuildContext context) {
    if (!isDefault) {
      return label ??
          buyPayoutMethodLabel(context, isLiquid: rail == BtcNetwork.liquid);
    }
    return rail == BtcNetwork.liquid
        ? context.loc.globalDefaultLiquidWalletLabel
        : context.loc.globalDefaultBitcoinWalletLabel;
  }
}

/// The network a buy pays out over, worded for the user. Shared by the wallet
/// dropdown and the review so that the two cannot drift.
String buyPayoutMethodLabel(BuildContext context, {required bool isLiquid}) {
  return isLiquid
      ? context.loc.buyPayoutMethodLiquid
      : context.loc.buyPayoutMethodBitcoin;
}
