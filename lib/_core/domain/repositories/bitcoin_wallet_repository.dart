import 'dart:typed_data';

import 'package:bb_mobile/_core/domain/entities/transaction.dart';
import 'package:bb_mobile/_core/domain/entities/tx_input.dart';

abstract class BitcoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  Future<Transaction> buildUnsigned({
    required String address,
    BigInt? amountSat,
    BigInt? absoluteFeeSat,
    double? feeRateSatPerVb,
    List<TxInput>? unspendableInputs, // Utxos that should not be used
    bool? drain,
    List<TxInput>? selectedInputs,
    bool replaceByFees,
  });
  Future<Transaction> sign(Transaction tx);
}
