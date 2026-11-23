import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/payin/exchange_payin_wallet.dart';

final class SellPayinSource {
  final ExchangePayinWallet? wallet;
  final BtcNetwork network;

  SellPayinSource.wallet(ExchangePayinWallet selectedWallet)
    : wallet = selectedWallet,
      network = selectedWallet.btcNetwork;

  const SellPayinSource.external(this.network) : wallet = null;
}
