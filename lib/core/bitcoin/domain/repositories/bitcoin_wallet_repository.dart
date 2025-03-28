import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';


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
