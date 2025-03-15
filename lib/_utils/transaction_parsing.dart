import 'package:bb_mobile/_core/domain/entities/tx_input.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;

class TransactionParsing {
  static Future<List<TxInput>> extractInputsFromPsbt(String psbt) async {
    final tx = await bdk.PartiallySignedTransaction.fromString(psbt);
    final inputs = await tx.extractTx().input();
    return inputs.map((input) {
      return TxInput(
        txId: input.previousOutput.txid,
        vout: input.previousOutput.vout,
        scriptPubkey: input.scriptSig.bytes,
      );
    }).toList();
  }
}
