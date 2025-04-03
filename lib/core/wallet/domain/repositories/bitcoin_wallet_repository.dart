import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entity/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/tx_input.dart';

abstract class BitcoinWalletRepository {
  Future<bool> isMine(Uint8List scriptBytes);
  Future<Transaction> buildUnsigned({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    List<TxInput>? unspendableInputs, // Utxos that should not be used
    bool? drain,
    List<TxInput>? selectedInputs,
    bool replaceByFees,
  });
  Future<Transaction> sign(Transaction tx);
}
