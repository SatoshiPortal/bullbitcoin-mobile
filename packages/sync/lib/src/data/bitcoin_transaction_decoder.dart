import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

/// A Bitcoin transaction as its bytes describe it, without any wallet view.
final class DecodedBitcoinTransaction {
  final String txid;
  final List<Outpoint> inputs;
  final List<DecodedBitcoinOutput> outputs;

  DecodedBitcoinTransaction({
    required this.txid,
    required List<Outpoint> inputs,
    required List<DecodedBitcoinOutput> outputs,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);
}

final class DecodedBitcoinOutput {
  final int valueSat;
  final Uint8List scriptPubkey;

  DecodedBitcoinOutput({
    required this.valueSat,
    required Uint8List scriptPubkey,
  }) : scriptPubkey = Uint8List.fromList(scriptPubkey).asUnmodifiableView();
}

/// Decodes a serialized transaction. Library function: no wallet is opened.
/// Synchronous for protocol code that maps sessions inside stream transforms.
/// Throws [FormatException] when [bytes] is not a transaction.
DecodedBitcoinTransaction decodeBitcoinTransaction(List<int> bytes) {
  final bdk.Transaction transaction;
  try {
    transaction = bdk.Transaction(transactionBytes: Uint8List.fromList(bytes));
  } on Exception {
    throw const FormatException('Not a Bitcoin transaction');
  }
  try {
    return _decode(transaction);
  } finally {
    transaction.dispose();
  }
}

/// Decodes the transaction a base64 PSBT carries, as extracted without
/// finalization checks beyond the native extractor's own.
/// Throws [FormatException] when [psbtBase64] is not a PSBT.
DecodedBitcoinTransaction decodeBitcoinPsbt(String psbtBase64) {
  final bdk.Psbt psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: psbtBase64);
  } on Exception {
    throw const FormatException('Not a PSBT');
  }
  try {
    final bdk.Transaction transaction;
    try {
      transaction = psbt.extractTx();
    } on Exception {
      throw const FormatException('PSBT transaction cannot be extracted');
    }
    try {
      return _decode(transaction);
    } finally {
      transaction.dispose();
    }
  } finally {
    psbt.dispose();
  }
}

DecodedBitcoinTransaction _decode(bdk.Transaction transaction) {
  final id = transaction.computeTxid();
  final String txid;
  try {
    txid = id.toString();
  } finally {
    id.dispose();
  }
  return DecodedBitcoinTransaction(
    txid: txid,
    inputs: [
      for (final input in transaction.input())
        (
          txId: input.previousOutput.txid.toString(),
          vout: input.previousOutput.vout,
        ),
    ],
    outputs: [
      for (final output in transaction.output())
        DecodedBitcoinOutput(
          valueSat: output.value.toSat(),
          scriptPubkey: output.scriptPubkey.toBytes(),
        ),
    ],
  );
}
