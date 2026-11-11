import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

final class SellPayinSourceV2 {
  final Wallet? wallet;
  final OrderBitcoinNetwork network;

  SellPayinSourceV2.wallet(Wallet selectedWallet)
    : wallet = selectedWallet,
      network = selectedWallet.isLiquid
          ? OrderBitcoinNetwork.liquid
          : OrderBitcoinNetwork.bitcoin;

  const SellPayinSourceV2.external(this.network) : wallet = null;
}
