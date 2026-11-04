import 'package:primitives/primitives.dart' show NetworkFee;
import 'wallet_coin_port.dart';

abstract interface class BitcoinSendPort {
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletCoinPort>? selected,
    bool? replaceByFee,
  });

  Future<int> getTxSize({required String psbt});

  Future<bool> isAddressOfWallet(String address, {required String walletId});
}
