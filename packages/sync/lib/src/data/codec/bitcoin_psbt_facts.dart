import 'dart:typed_data';

import 'package:primitives/primitives.dart';

import '../bitcoin_transaction_decoder.dart';

/// Internal PSBT evidence, not chain membership or signature verification.
final class BitcoinPsbtFacts {
  final String unsignedTxid;
  final int feeSat;
  final List<BitcoinPsbtInputFacts> inputs;
  final List<DecodedBitcoinOutput> outputs;

  /// Present only when every input has a final field, even an empty one. Structural extraction does not prove script validity. A host comparing another raw transaction must compare all consensus bytes, including witnesses, not merely txids.
  final DecodedBitcoinTransaction? finalTransaction;

  BitcoinPsbtFacts({
    required this.unsignedTxid,
    required this.feeSat,
    required List<BitcoinPsbtInputFacts> inputs,
    required List<DecodedBitcoinOutput> outputs,
    required this.finalTransaction,
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs);
}

/// One input in unsigned-transaction order. Prevout facts are internally consistent PSBT evidence; a witness UTXO alone does not authenticate a chain output.
final class BitcoinPsbtInputFacts {
  final Outpoint outpoint;
  final int prevoutValueSat;
  final Uint8List prevoutScriptPubkey;
  final Uint8List? finalScriptSig;
  final List<Uint8List>? finalScriptWitness;
  final bool hasPartialSignatures;
  final bool hasTaprootKeySignature;
  final bool hasTaprootScriptSignatures;

  BitcoinPsbtInputFacts({
    required this.outpoint,
    required this.prevoutValueSat,
    required List<int> prevoutScriptPubkey,
    required List<int>? finalScriptSig,
    required List<List<int>>? finalScriptWitness,
    required this.hasPartialSignatures,
    required this.hasTaprootKeySignature,
    required this.hasTaprootScriptSignatures,
  }) : prevoutScriptPubkey = _copy(prevoutScriptPubkey),
       finalScriptSig = finalScriptSig == null ? null : _copy(finalScriptSig),
       finalScriptWitness = finalScriptWitness == null
           ? null
           : List.unmodifiable(finalScriptWitness.map(_copy));

  /// Field presence, including empty fields; partial signatures are separate evidence and never imply finalisation.
  bool get hasFinalFields =>
      finalScriptSig != null || finalScriptWitness != null;

  /// A nonempty stack, not a verified signature or a guarantee of nonempty stack items.
  bool get hasFinalWitness => finalScriptWitness?.isNotEmpty ?? false;
}

Uint8List _copy(List<int> bytes) =>
    Uint8List.fromList(bytes).asUnmodifiableView();
