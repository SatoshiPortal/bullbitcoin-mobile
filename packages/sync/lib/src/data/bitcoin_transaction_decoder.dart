import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import 'codec/native_bitcoin_transaction.dart';

/// A consensus-valid transaction never exceeds 4,000,000 weight units, so its
/// serialization never exceeds this many bytes.
const maxBitcoinTransactionBytes = 4000000;

/// PSBTs carry previous transactions; the bound keeps hostile input from
/// reaching the native parser, not from describing a valid PSBT.
const maxEncodedBitcoinPsbtLength = 16 * 1024 * 1024;

/// A Bitcoin transaction as its bytes describe it, without any wallet view.
/// [bytes] is its consensus serialization, witnesses included when present.
final class DecodedBitcoinTransaction {
  final String txid;
  final int version;
  final int locktime;
  final int size;
  final int vsize;

  /// The outpoints spent, in input order.
  final List<Outpoint> inputs;

  /// The same inputs, in the same order, with their sequence and scriptSig.
  final List<DecodedBitcoinInput> inputDetails;
  final List<DecodedBitcoinOutput> outputs;
  final Uint8List bytes;

  DecodedBitcoinTransaction({
    required this.txid,
    required this.version,
    required this.locktime,
    required this.size,
    required this.vsize,
    required List<DecodedBitcoinInput> inputDetails,
    required List<DecodedBitcoinOutput> outputs,
    required List<int> bytes,
  }) : inputs = List.unmodifiable([
         for (final input in inputDetails) input.outpoint,
       ]),
       inputDetails = List.unmodifiable(inputDetails),
       outputs = List.unmodifiable(outputs),
       bytes = Uint8List.fromList(bytes).asUnmodifiableView();
}

final class DecodedBitcoinInput {
  final Outpoint outpoint;
  final int sequence;
  final Uint8List scriptSig;

  DecodedBitcoinInput({
    required this.outpoint,
    required this.sequence,
    required List<int> scriptSig,
  }) : scriptSig = Uint8List.fromList(scriptSig).asUnmodifiableView();
}

/// One output, in its serialized order.
final class DecodedBitcoinOutput {
  final int valueSat;
  final Uint8List scriptPubkey;

  DecodedBitcoinOutput({
    required this.valueSat,
    required List<int> scriptPubkey,
  }) : scriptPubkey = Uint8List.fromList(scriptPubkey).asUnmodifiableView();
}

/// Decodes a serialized transaction. Library function: no wallet is opened.
/// Synchronous for protocol code that maps sessions inside stream transforms.
/// Throws [FormatException] when [bytes] is not a transaction.
DecodedBitcoinTransaction decodeBitcoinTransaction(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > maxBitcoinTransactionBytes) {
    throw const FormatException('Not a Bitcoin transaction');
  }
  final bdk.Transaction transaction;
  try {
    transaction = bdk.Transaction(transactionBytes: Uint8List.fromList(bytes));
  } on Exception {
    throw const FormatException('Not a Bitcoin transaction');
  }
  try {
    return decodeNativeTransaction(transaction);
  } finally {
    transaction.dispose();
  }
}

/// Decodes the transaction a base64 PSBT carries, witnesses included only
/// when its inputs are finalized. The extraction checks the fee rate, so a
/// PSBT without its input amounts is refused.
/// Throws [FormatException] when [psbtBase64] is not a PSBT.
DecodedBitcoinTransaction decodeBitcoinPsbt(String psbtBase64) {
  if (psbtBase64.isEmpty || psbtBase64.length > maxEncodedBitcoinPsbtLength) {
    throw const FormatException('Not a PSBT');
  }
  final bdk.Psbt psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: psbtBase64);
  } on Exception {
    throw const FormatException('Not a PSBT');
  }
  try {
    return decodeNativePsbt(psbt);
  } finally {
    psbt.dispose();
  }
}
