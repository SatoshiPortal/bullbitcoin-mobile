import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/payin/exchange_payin_wallet.dart';

final class SellPayinSource {
  final ExchangePayinWallet? wallet;
  final OrderBitcoinNetwork network;

  SellPayinSource.wallet(ExchangePayinWallet selectedWallet)
    : wallet = selectedWallet,
      network = selectedWallet.isLiquid
          ? OrderBitcoinNetwork.liquid
          : OrderBitcoinNetwork.bitcoin;

  const SellPayinSource.external(this.network) : wallet = null;
}
