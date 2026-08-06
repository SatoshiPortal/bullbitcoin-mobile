import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

abstract interface class BitcoinSendPort {
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  });

  Future<int> getTxSize({required String psbt});

  Future<bool> isAddressOfWallet(String address, {required String walletId});
}
