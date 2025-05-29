import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';

abstract class BitcoinWalletRepository {
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>?
    unspendable, // TODO: Change to List<WalletUtxo> when FrozenUtxoRepository is implemented
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  });
  Future<int> getTxSize({required String psbt});
  Future<int> getTxFeeAmount({required String psbt});
  Future<String> signPsbt(String psbt, {required String walletId});
  Future<bool> isScriptOfWallet({
    required String walletId,
    required Uint8List script,
  });
}
