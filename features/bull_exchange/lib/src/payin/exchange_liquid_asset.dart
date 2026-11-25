import 'package:bip21_uri/bip21_uri.dart';
import 'package:primitives/primitives.dart' show AssetConstants;

/// The Liquid asset the exchange pays out and takes in.
abstract final class ExchangeLiquidAsset {
  /// The L-BTC asset id of the network an order was placed on. Regtest has
  /// no exchange.
  static String idFor({required bool isTestnet}) =>
      isTestnet ? AssetConstants.lbtcTestnet : AssetConstants.lbtcMainnet;

  /// The payment link a wallet pays a Liquid payin of [amountBtc] to
  /// [address] with, carrying the L-BTC asset id of the order's network.
  static String paymentUri({
    required String address,
    required double amountBtc,
    required bool isTestnet,
  }) => Bip21Uri(
    scheme: 'liquidnetwork',
    address: address,
    amount: amountBtc,
    options: {'assetid': idFor(isTestnet: isTestnet)},
  ).toString();
}
