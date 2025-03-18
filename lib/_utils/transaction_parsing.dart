import 'package:bb_mobile/_core/domain/entities/tx_input.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:flutter/foundation.dart';

class TransactionParsing {
  static Future<List<TxInput>> extractInputsFromPsbt(String psbt) async {
    debugPrint('Extracting inputs from psbt: $psbt');
    final tx = await bdk.PartiallySignedTransaction.fromString(psbt);
    final inputs = await tx.extractTx().input();
    final txInputs = inputs.map((input) {
      return TxInput(
        txId: input.previousOutput.txid,
        vout: input.previousOutput.vout,
        scriptPubkey: input.scriptSig.bytes,
      );
    }).toList();
    debugPrint('Extracted inputs: $inputs');
    return txInputs;
  }

  static Future<String> getTxIdFromPsbt(String psbt) async {
    final tx = await bdk.PartiallySignedTransaction.fromString(psbt);
    return tx.extractTx().txid();
  }
}
