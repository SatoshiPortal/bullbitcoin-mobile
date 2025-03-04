import 'dart:typed_data';

import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

abstract class PayjoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  // Todo: change bdk.LocalUtxo to a utxo entity
  Future<List<bdk.LocalUtxo>> listUnspent();
  Future<String> buildPsbt({
    required String address,
    required BigInt amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
  });
  Future<String> signPsbt(String psbt);
  Future<String> getTxIdFromPsbt(String psbt);
  Future<bool> hasTransaction(String txId);
  Future<String> getTxIdFromTxBytes(List<int> bytes);
}
