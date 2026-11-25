import 'package:exchange/exchange.dart' show BtcNetwork;
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show WalletKey;

/// The exact local wallet selected in the payin flow, with its displayed balance.
final class ExchangePayinWallet {
  final WalletKey key;
  final BigInt? balanceSat;
  final String? label;
  final bool isDefault;

  const ExchangePayinWallet({
    required this.key,
    required this.balanceSat,
    this.label,
    this.isDefault = false,
  });

  String get id => key.id;
  bool get isLiquid => key.network is LiquidNetwork;
  BtcNetwork get btcNetwork =>
      isLiquid ? BtcNetwork.liquid : BtcNetwork.bitcoin;
}
