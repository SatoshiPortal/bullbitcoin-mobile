import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:primitives/primitives.dart';

import '../bitcoin_transaction_decoder.dart';
import '../../domain/sync_failure.dart';
import '../../domain/wallet_values.dart' show Keychain;
import 'native_bitcoin_transaction.dart';
import 'bitcoin_psbt_facts.dart';
import 'psbt_unsigned_transaction.dart';

/// The PSBT re-serialized by the parser: a check that [psbtBase64] is a PSBT.
Result<String, SyncFailure> canonicalBitcoinPsbt(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) => Ok(psbt.serialize()));

/// Combines a signer's [signedBase64] with the [unsignedBase64] it was given
/// (a signer may drop the input data) and finalizes the result.
Result<DecodedBitcoinTransaction, SyncFailure> finalizeBitcoinPsbts({
  required String unsignedBase64,
  required String signedBase64,
}) => _withPsbt(
  unsignedBase64,
  (unsigned) => _withPsbt(signedBase64, (signed) {
    final bdk.Psbt combined;
    try {
      combined = unsigned.combine(other: signed);
    } on Exception {
      return const Err(SyncNotFinalizableFailure());
    }
    try {
      final finalized = combined.finalize();
      try {
        if (!finalized.couldFinalize) {
          return const Err(SyncNotFinalizableFailure());
        }
        return Ok(decodeNativePsbt(finalized.psbt));
      } finally {
        finalized.psbt.dispose();
      }
    } finally {
      combined.dispose();
    }
  }),
);

/// The fee a PSBT pays: its inputs' amounts less its outputs'. Refused when
/// an input amount is missing.
Result<int, SyncFailure> bitcoinPsbtFee(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) => Ok(psbt.fee()));

/// Reads only the unsigned skeleton. A signer may have removed the input
/// metadata required by the fee-checked transaction extractor.
@useResult
Result<DecodedBitcoinTransaction, SyncFailure> bitcoinPsbtSkeleton(
  String psbtBase64,
) => _withPsbt(
  psbtBase64,
  (psbt) =>
      Ok(decodeBitcoinTransaction(psbtUnsignedTransaction(psbt.serialize()))),
);

/// Inspects PSBT evidence without opening a wallet or finalising/signing anything. Missing or contradictory UTXOs refuse; structural final fields never establish valid signatures. Hosts must compare finalTransaction.bytes with every byte of their independently decoded raw transaction, witnesses included.
@useResult
Result<BitcoinPsbtFacts, SyncFailure> inspectBitcoinPsbt(String psbtBase64) =>
    _withPsbt(psbtBase64, (psbt) {
      final unsigned = decodeBitcoinTransaction(
        psbtUnsignedTransaction(psbt.serialize()),
      );
      final inputs = psbt.input();
      try {
        if (inputs.isEmpty || inputs.length != unsigned.inputs.length) {
          throw const FormatException('PSBT inputs');
        }
        final facts = <BitcoinPsbtInputFacts>[];
        var totalInput = 0;
        for (var index = 0; index < inputs.length; index++) {
          final input = inputs[index];
          final outpoint = unsigned.inputs[index];
          DecodedBitcoinOutput? prevout;
          if (input.nonWitnessUtxo case final previous?) {
            if (previous.totalSize() > maxBitcoinTransactionBytes) {
              throw const FormatException('PSBT previous transaction size');
            }
            final decoded = decodeNativeTransaction(previous);
            if (decoded.txid != outpoint.txId ||
                outpoint.vout < 0 ||
                outpoint.vout >= decoded.outputs.length) {
              throw const FormatException('PSBT previous transaction');
            }
            prevout = decoded.outputs[outpoint.vout];
          }
          if (input.witnessUtxo case final witness?) {
            final value = witness.value.toSat();
            final script = witness.scriptPubkey.toBytes();
            if (prevout != null &&
                (prevout.valueSat != value ||
                    !_equalBytes(prevout.scriptPubkey, script))) {
              throw const FormatException('PSBT contradictory UTXO');
            }
            prevout = DecodedBitcoinOutput(
              valueSat: value,
              scriptPubkey: script,
            );
          }
          if (prevout == null) {
            throw const FormatException('PSBT missing UTXO');
          }
          totalInput = _addBitcoinAmount(totalInput, prevout.valueSat);
          facts.add(
            BitcoinPsbtInputFacts(
              outpoint: outpoint,
              prevoutValueSat: prevout.valueSat,
              prevoutScriptPubkey: prevout.scriptPubkey,
              finalScriptSig: input.finalScriptSig?.toBytes(),
              finalScriptWitness: input.finalScriptWitness,
              hasPartialSignatures: input.partialSigs.isNotEmpty,
              hasTaprootKeySignature: input.tapKeySig != null,
              hasTaprootScriptSignatures: input.tapScriptSigs.isNotEmpty,
            ),
          );
        }
        var totalOutput = 0;
        for (final output in unsigned.outputs) {
          totalOutput = _addBitcoinAmount(totalOutput, output.valueSat);
        }
        if (totalOutput > totalInput) {
          throw const FormatException('PSBT negative fee');
        }
        DecodedBitcoinTransaction? finalTransaction;
        if (facts.every((input) => input.hasFinalFields)) {
          final transaction = psbt.extractTx();
          try {
            if (transaction.totalSize() > maxBitcoinTransactionBytes) {
              throw const FormatException('PSBT final transaction size');
            }
            finalTransaction = decodeNativeTransaction(transaction);
          } finally {
            transaction.dispose();
          }
          if (finalTransaction.version != unsigned.version ||
              finalTransaction.locktime != unsigned.locktime ||
              finalTransaction.inputs.length != unsigned.inputs.length ||
              finalTransaction.outputs.length != unsigned.outputs.length) {
            throw const FormatException('PSBT final transaction');
          }
          for (var index = 0; index < facts.length; index++) {
            if (finalTransaction.inputs[index] != unsigned.inputs[index] ||
                finalTransaction.inputDetails[index].sequence !=
                    unsigned.inputDetails[index].sequence) {
              throw const FormatException('PSBT final inputs');
            }
          }
          for (var index = 0; index < unsigned.outputs.length; index++) {
            final original = unsigned.outputs[index];
            final actual = finalTransaction.outputs[index];
            if (original.valueSat != actual.valueSat ||
                !_equalBytes(original.scriptPubkey, actual.scriptPubkey)) {
              throw const FormatException('PSBT final outputs');
            }
          }
        }
        return Ok(
          BitcoinPsbtFacts(
            unsignedTxid: unsigned.txid,
            feeSat: totalInput - totalOutput,
            inputs: facts,
            outputs: unsigned.outputs,
            finalTransaction: finalTransaction,
          ),
        );
      } finally {
        // input() eagerly creates the whole vector. Dispose every nested native object, including later inputs skipped by an earlier refusal. ControlBlock and the signature/key/preimage records contain Dart values only in this pinned API.
        for (final input in inputs) {
          input.nonWitnessUtxo?.dispose();
          input.witnessUtxo?.value.dispose();
          input.witnessUtxo?.scriptPubkey.dispose();
          input.redeemScript?.dispose();
          input.witnessScript?.dispose();
          input.finalScriptSig?.dispose();
          for (final source in input.bip32Derivation.values) {
            source.path.dispose();
          }
          for (final origin in input.tapKeyOrigins.values) {
            origin.keySource.path.dispose();
          }
          for (final script in input.tapScripts.values) {
            script.script.dispose();
          }
        }
      }
    });

const _maxBitcoinMoney = 21000000 * 100000000;

int _addBitcoinAmount(int total, int value) {
  if (value < 0 || value > _maxBitcoinMoney - total) {
    throw const FormatException('PSBT monetary bounds');
  }
  return total + value;
}

bool _equalBytes(List<int> a, List<int> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((index) => a[index] == b[index]);

/// The public output descriptor of [keychain] for the account key [xpub],
/// with its key origin: BIP84, BIP49 or BIP44 by [scriptType]. Library
/// function: no wallet is opened.
Result<String, SyncFailure> bitcoinPublicDescriptor({
  required String xpub,
  required String fingerprint,
  required ScriptType scriptType,
  required Keychain keychain,
  required BitcoinNetwork network,
}) {
  final kind = network == BitcoinNetwork.mainnet
      ? bdk.NetworkKind.main
      : bdk.NetworkKind.test;
  final nativeKeychain = keychain == Keychain.internal
      ? bdk.KeychainKind.internal
      : bdk.KeychainKind.external_;
  final bdk.DescriptorPublicKey key;
  try {
    key = bdk.DescriptorPublicKey.fromString(publicKey: xpub);
  } on Exception {
    return const Err(SyncInvalidCatalogFailure());
  }
  try {
    final descriptor = switch (scriptType) {
      ScriptType.bip84 => bdk.Descriptor.newBip84Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
      ScriptType.bip49 => bdk.Descriptor.newBip49Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
      ScriptType.bip44 => bdk.Descriptor.newBip44Public(
        publicKey: key,
        fingerprint: fingerprint,
        keychainKind: nativeKeychain,
        networkKind: kind,
      ),
    };
    try {
      return Ok(descriptor.toString());
    } finally {
      descriptor.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidCatalogFailure());
  } finally {
    key.dispose();
  }
}

/// The address an output [script] pays to on [network], for display. A
/// non-standard script has none.
Result<String, SyncFailure> bitcoinScriptAddress(
  List<int> script,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final nativeScript = bdk.Script(
      rawOutputScript: Uint8List.fromList(script),
    );
    try {
      final address = bdk.Address.fromScript(
        script: nativeScript,
        network: native,
      );
      try {
        return Ok(address.toString());
      } finally {
        address.dispose();
      }
    } finally {
      nativeScript.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

/// [address] in its canonical form when it is valid on [network]. Testnet
/// also accepts the historical Base58 encodings it shares with regtest.
Result<String, SyncFailure> parseBitcoinAddress(
  String address,
  BitcoinNetwork network,
) {
  final native = _nativeNetwork(network);
  if (native == null) return const Err(SyncUnsupportedNetworkFailure());
  try {
    final parsed = bdk.Address(address: address, network: native);
    try {
      return Ok(parsed.toString());
    } finally {
      parsed.dispose();
    }
  } on Exception {
    return const Err(SyncInvalidAddressFailure());
  }
}

bdk.Network? _nativeNetwork(BitcoinNetwork network) => switch (network) {
  BitcoinNetwork.mainnet => bdk.Network.bitcoin,
  BitcoinNetwork.testnet => bdk.Network.testnet,
  BitcoinNetwork.regtest => bdk.Network.regtest,
  BitcoinNetwork.signet => null,
};

Result<T, SyncFailure> _withPsbt<T>(
  String psbtBase64,
  Result<T, SyncFailure> Function(bdk.Psbt) read,
) {
  if (psbtBase64.isEmpty || psbtBase64.length > maxEncodedBitcoinPsbtLength) {
    return const Err(SyncInvalidTransactionFailure());
  }
  final bdk.Psbt psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: psbtBase64);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  }
  try {
    return read(psbt);
  } on Exception {
    return const Err(SyncInvalidTransactionFailure());
  } finally {
    psbt.dispose();
  }
}
