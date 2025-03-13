import 'dart:typed_data';

import 'package:bb_mobile/_core/domain/entities/utxo.dart';

abstract class PayjoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  Future<List<Utxo>> listUnspent();
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
