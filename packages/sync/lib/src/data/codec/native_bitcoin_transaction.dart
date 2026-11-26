import 'package:rust_bindings/bdk.dart' as bdk;

import '../bitcoin_transaction_decoder.dart';

// Shared by the decoder and the codecs; never exported: its signatures carry
// native types.

/// The transaction [psbt] carries; it stays owned by the caller.
DecodedBitcoinTransaction decodeNativePsbt(bdk.Psbt psbt) {
  final bdk.Transaction transaction;
  try {
    transaction = psbt.extractTx();
  } on Exception {
    throw const FormatException('PSBT transaction cannot be extracted');
  }
  try {
    return decodeNativeTransaction(transaction);
  } finally {
    transaction.dispose();
  }
}

/// [transaction] stays owned by the caller.
DecodedBitcoinTransaction decodeNativeTransaction(bdk.Transaction transaction) {
  final txid = transaction.computeTxid();
  final inputs = transaction.input();
  final outputs = transaction.output();
  try {
    return DecodedBitcoinTransaction(
      txid: txid.toString(),
      version: transaction.version(),
      locktime: transaction.lockTime(),
      size: transaction.totalSize(),
      vsize: transaction.vsize(),
      inputDetails: [
        for (final input in inputs)
          DecodedBitcoinInput(
            outpoint: (
              txId: input.previousOutput.txid.toString(),
              vout: input.previousOutput.vout,
            ),
            sequence: input.sequence,
            scriptSig: input.scriptSig.toBytes(),
          ),
      ],
      outputs: [
        for (final output in outputs)
          DecodedBitcoinOutput(
            valueSat: output.value.toSat(),
            scriptPubkey: output.scriptPubkey.toBytes(),
          ),
      ],
      bytes: transaction.serialize(),
    );
  } finally {
    txid.dispose();
    for (final input in inputs) {
      input.previousOutput.txid.dispose();
      input.scriptSig.dispose();
    }
    for (final output in outputs) {
      output.value.dispose();
      output.scriptPubkey.dispose();
    }
  }
}
