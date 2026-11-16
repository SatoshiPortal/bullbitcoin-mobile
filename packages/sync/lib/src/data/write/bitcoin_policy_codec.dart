import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bitcoin_base/bitcoin_base.dart' as bitcoin_base;
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart';

import '../../domain/bitcoin_policy_descriptor.dart';
import '../../domain/parsed_bitcoin_policy.dart';
import '../../domain/bitcoin_psbt_inspection.dart';
import '../../domain/bitcoin_hash_preimage.dart';
import '../../domain/wallet_values.dart';
import '../../domain/sync_failure.dart';
import '../codec/public_account_key.dart';
import '../codec/descriptor_key_matcher.dart';
import '../codec/bitcoin_psbt_encoding.dart';
import 'policy_codec_exceptions.dart';

part 'descriptor_codec.dart';
part 'policy_mapper.dart';
part 'psbt_verification.dart';

/// Parses public descriptors and validates signer payloads without opening a
/// persistent wallet. Scratch descriptors contain no secrets or chain state.
final class BitcoinPolicyCodec {
  const BitcoinPolicyCodec();

  Result<ParsedBitcoinDescriptor, SyncFailure> parseDescriptor({
    required String descriptor,
    required BitcoinNetwork network,
  }) => _read(
    () => _DescriptorCodec.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      network: network,
    ),
    descriptor: true,
  );

  Result<String, SyncFailure> combineDescriptorPair({
    required String externalDescriptor,
    required String internalDescriptor,
    required BitcoinNetwork network,
  }) => _read(
    () => _DescriptorCodec.combinePublicDescriptorPair(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network,
    ),
    descriptor: true,
  );

  Result<ParsedBitcoinPolicy, SyncFailure> analyzePolicy({
    required BitcoinPolicyDescriptor wallet,
    List<BitcoinDescriptorKey> descriptorKeys = const [],
  }) => _read(
    () => _BitcoinPolicyCodec().analyzePolicy(
      wallet: wallet,
      descriptorKeys: descriptorKeys,
    ),
    descriptor: true,
  );

  Result<BitcoinPsbtInspection, SyncFailure> inspectPsbt(
    String psbt, {
    required BitcoinPolicyDescriptor wallet,
    required Set<String> walletFingerprints,
    OwnershipIndex? ownership,
  }) => _read(
    () => _BitcoinPolicyCodec().inspectPsbt(
      psbt,
      wallet: wallet,
      walletFingerprints: walletFingerprints,
      ownershipIndex: ownership,
    ),
  );

  Result<int, SyncFailure> transactionVsize(
    String psbt, {
    required BitcoinPolicyDescriptor wallet,
  }) => _read(() => _BitcoinPolicyCodec().decodeTxSize(psbt, wallet: wallet));

  Result<({String psbt, bool signWithTapInternalKey}), SyncFailure>
  prepareSigning(String psbt, {OwnershipIndex? foreignInputWallet}) => _read(
    () => _BitcoinPolicyCodec().preparePsbtForSigning(
      psbt,
      foreignInputWallet: foreignInputWallet,
    ),
  );

  Result<void, SyncFailure> validateInputs(
    String psbt, {
    required OwnershipIndex ownership,
    Set<String> frozenOutpoints = const {},
    String? replacingTxid,
    bool allowSpentWalletInputs = false,
  }) => _read(
    () => _validateOwnedInputs(
      psbt,
      ownership: ownership,
      frozenOutpoints: frozenOutpoints,
      replacingTxid: replacingTxid,
      allowSpentWalletInputs: allowSpentWalletInputs,
    ),
  );

  Result<bool, SyncFailure> validatePreimage(BitcoinHashPreimage preimage) =>
      _read(() => _BitcoinPolicyCodec().validatePolicyPreimage(preimage));

  Result<String, SyncFailure> applyPreimages(
    String psbt,
    List<BitcoinHashPreimage> preimages,
  ) => _read(() => _BitcoinPolicyCodec().applyPolicyPreimages(psbt, preimages));

  Result<({String transaction, int txSize}), SyncFailure>
  verifyFinalTransaction({
    required String psbtBase64,
    required String transactionHex,
  }) => _read(
    () => _BitcoinPolicyCodec().verifyFinalTransaction(
      psbtBase64: psbtBase64,
      transactionHex: transactionHex,
    ),
  );

  Result<({String psbt, bool isFinalized}), SyncFailure> completeSigning({
    required String originalPsbt,
    required String signedPsbt,
    bool tryFinalize = true,
  }) => _read(
    () => _BitcoinPolicyCodec().completePsbtSigning(
      originalPsbt: originalPsbt,
      signedPsbt: signedPsbt,
      tryFinalize: tryFinalize,
    ),
  );

  Result<String, SyncFailure> combinePsbts({
    required String first,
    required String second,
  }) => _read(
    () => _BitcoinPolicyCodec().combinePsbts(first: first, second: second),
  );

  Result<String, SyncFailure> validateExternalPartialPsbt({
    required String currentPsbtBase64,
    required String signedPsbtBase64,
  }) => _read(
    () => _BitcoinPolicyCodec().validateExternalPartialPsbt(
      currentPsbtBase64: currentPsbtBase64,
      signedPsbtBase64: signedPsbtBase64,
    ),
  );

  Result<({String psbt, bool isFinalized}), SyncFailure> finalizePsbt(
    String psbt,
  ) => _read(() => _BitcoinPolicyCodec().finalizePsbt(psbt));
}

Result<T, SyncFailure> _read<T>(T Function() read, {bool descriptor = false}) {
  try {
    return Ok(read());
  } on Exception catch (error) {
    return Err(
      SyncPolicyFailure(switch (error) {
        UnsupportedFixedPublicKeyDescriptorException() =>
          PolicyFailureReason.fixedPublicKey,
        UnsupportedBitcoinPolicyPathException() =>
          PolicyFailureReason.unsupportedPath,
        BitcoinPsbtWalletMismatchException() =>
          PolicyFailureReason.walletMismatch,
        BitcoinPsbtMissingLocalOriginException() =>
          PolicyFailureReason.missingOrigin,
        BitcoinPsbtMissingUtxoException() => PolicyFailureReason.missingUtxo,
        BitcoinPsbtFrozenUtxoException() => PolicyFailureReason.frozenUtxo,
        BitcoinPsbtUnsupportedSighashException() =>
          PolicyFailureReason.unsupportedSighash,
        BitcoinPsbtUnsupportedSpendModeException() =>
          PolicyFailureReason.unsupportedSpendMode,
        _ =>
          descriptor
              ? PolicyFailureReason.invalidDescriptor
              : PolicyFailureReason.invalidPsbt,
      }),
    );
  }
}

void _validateOwnedInputs(
  String psbtBase64, {
  required OwnershipIndex ownership,
  required Set<String> frozenOutpoints,
  required String? replacingTxid,
  required bool allowSpentWalletInputs,
}) {
  final replaced = replacingTxid == null
      ? const <Outpoint>[]
      : ownership.transactionInputs[replacingTxid];
  if (replaced == null) throw const BitcoinPsbtMissingUtxoException();
  final psbt = _parsePsbt(psbtBase64);
  try {
    final transaction = psbt.extractTx();
    try {
      final transactionInputs = transaction.input();
      final inputs = psbt.input();
      if (transactionInputs.length != inputs.length) {
        throw const InvalidBitcoinPsbtException();
      }
      final seen = <Outpoint>{};
      for (final (index, input) in transactionInputs.indexed) {
        final outpoint = (
          txId: input.previousOutput.txid.toString(),
          vout: input.previousOutput.vout,
        );
        if (!seen.add(outpoint)) throw const InvalidBitcoinPsbtException();
        if (frozenOutpoints.contains('${outpoint.txId}:${outpoint.vout}')) {
          throw const BitcoinPsbtFrozenUtxoException();
        }
        final local = ownership.outputs[outpoint];
        if (local == null ||
            (local.isSpent &&
                !allowSpentWalletInputs &&
                !replaced.contains(outpoint))) {
          throw const BitcoinPsbtMissingUtxoException();
        }
        final supplied = _inputUtxo(inputs[index], input.previousOutput);
        if (BigInt.from(supplied.value.toSat()) != local.amountSat ||
            !_sameBytes(supplied.scriptPubkey.toBytes(), local.scriptPubkey)) {
          throw const InvalidBitcoinPsbtException();
        }
      }
    } finally {
      transaction.dispose();
    }
  } finally {
    psbt.dispose();
  }
}

/// Writer-internal normalization: remove unspendable NUMS origins and retain
/// only the requested signing paths on the transaction the writer just built.
String prepareBuiltPolicyPsbt(
  String psbtBase64, {
  required Map<Outpoint, Keychain> keychains,
  required ({
    List<BitcoinDescriptorKey> external,
    List<BitcoinDescriptorKey> internal,
  })?
  requiredKeys,
}) {
  final psbt = _parsePsbt(psbtBase64);
  try {
    final inputs = psbt.input();
    final normalized = _removeFixedBip341NumsKeyOrigins(
      psbt.serialize(),
      inputs: inputs,
      outputs: psbt.output(),
    );
    if (requiredKeys == null) return normalized;
    final transaction = psbt.extractTx();
    try {
      final inputKeychains = [
        for (final input in transaction.input())
          switch (keychains[(
            txId: input.previousOutput.txid.toString(),
            vout: input.previousOutput.vout,
          )]) {
            Keychain.external => bdk.KeychainKind.external_,
            Keychain.internal => bdk.KeychainKind.internal,
            null => throw const BitcoinPsbtMissingUtxoException(),
          },
      ];
      final selected = _retainSelectedSegwitKeyOrigins(
        normalized,
        inputKeychains: inputKeychains,
        requiredDescriptorKeys: requiredKeys,
      );
      return _retainSelectedTaprootSpendPaths(
        selected,
        inputs: inputs,
        inputKeychains: inputKeychains,
        requiredDescriptorKeys: requiredKeys,
      );
    } finally {
      transaction.dispose();
    }
  } finally {
    psbt.dispose();
  }
}

class _BitcoinPolicyCodec {
  int decodeTxSize(
    String psbtString, {
    required BitcoinPolicyDescriptor wallet,
  }) {
    final psbt = _parsePsbt(psbtString);
    try {
      final transaction = psbt.extractTx();
      try {
        final transactionInputs = transaction.input();
        final psbtInputs = psbt.input();
        if (transactionInputs.length != psbtInputs.length) {
          throw const InvalidBitcoinPsbtException();
        }
        if (psbtInputs.every(_isFinalizedInput)) return transaction.vsize();
        final descriptorWallet =
            _DescriptorCodec.createEphemeralDescriptorWallet(
              descriptor: wallet.descriptor,
              network: wallet.network,
            );
        try {
          final keychains = <Keychain>[];
          for (final (index, input) in psbtInputs.indexed) {
            final utxo = _inputUtxo(
              input,
              transactionInputs[index].previousOutput,
            );
            final ownership = _descriptorOwnership(
              descriptorWallet,
              script: utxo.scriptPubkey,
              keySources: [
                ...input.bip32Derivation.values,
                ...input.tapKeyOrigins.values.map((origin) => origin.keySource),
              ],
            );
            if (ownership == null) {
              throw const BitcoinPsbtWalletMismatchException();
            }
            keychains.add(ownership.keychain);
          }
          return _completedTransactionVsize(
            transaction: transaction,
            inputs: psbtInputs,
            inputKeychains: keychains,
            wallet: wallet,
          );
        } finally {
          descriptorWallet.dispose();
        }
      } finally {
        transaction.dispose();
      }
    } finally {
      psbt.dispose();
    }
  }

  bool validatePolicyPreimage(BitcoinHashPreimage preimage) {
    final input = _psbtPreimage(preimage);
    return hex.encode(_preimageHash(input)) == preimage.hash;
  }

  String applyPolicyPreimages(
    String psbtBase64,
    List<BitcoinHashPreimage> preimages,
  ) {
    final parsed = _parsePsbt(psbtBase64);
    final String normalizedPsbt;
    try {
      normalizedPsbt = parsed.serialize();
    } finally {
      parsed.dispose();
    }
    if (preimages.isEmpty) return normalizedPsbt;
    final psbt = bitcoin_base.Psbt.fromBase64(normalizedPsbt);
    final inputs = [for (final preimage in preimages) _psbtPreimage(preimage)];
    for (var index = 0; index < psbt.input.length; index++) {
      psbt.input.updateInputs(index, inputs);
    }
    return psbt.toBase64();
  }

  ({String transaction, int txSize}) verifyFinalTransaction({
    required String psbtBase64,
    required String transactionHex,
  }) {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final prepared = psbt.extractTx();
      try {
        final signed = bdk.Transaction(
          transactionBytes: Uint8List.fromList(hex.decode(transactionHex)),
        );
        try {
          final preparedInputs = prepared.input();
          final psbtInputs = psbt.input();
          if (preparedInputs.length != psbtInputs.length) {
            throw const FormatException('Invalid prepared PSBT');
          }
          final hasTaprootInput = Iterable<int>.generate(preparedInputs.length)
              .any((index) {
                final script = _inputUtxo(
                  psbtInputs[index],
                  preparedInputs[index].previousOutput,
                ).scriptPubkey.toBytes();
                return script.length == 34 &&
                    script[0] == 0x51 &&
                    script[1] == 0x20;
              });
          if (hasTaprootInput) {
            throw const FormatException(
              'Finalized Taproot transactions are not supported; return a PSBT',
            );
          }
          final signedInputs = signed.input();
          final preparedOutputs = prepared.output();
          final signedOutputs = signed.output();

          final sameHeader =
              prepared.version() == signed.version() &&
              prepared.lockTime() == signed.lockTime();
          final sameInputs =
              preparedInputs.length == signedInputs.length &&
              Iterable<int>.generate(preparedInputs.length).every((index) {
                final expected = preparedInputs[index];
                final actual = signedInputs[index];
                return expected.previousOutput.txid.toString() ==
                        actual.previousOutput.txid.toString() &&
                    expected.previousOutput.vout ==
                        actual.previousOutput.vout &&
                    expected.sequence == actual.sequence;
              });
          final sameOutputs =
              preparedOutputs.length == signedOutputs.length &&
              Iterable<int>.generate(preparedOutputs.length).every((index) {
                final expected = preparedOutputs[index];
                final actual = signedOutputs[index];
                return expected.value.toSat() == actual.value.toSat() &&
                    listEquals(
                      expected.scriptPubkey.toBytes(),
                      actual.scriptPubkey.toBytes(),
                    );
              });
          final hasOnlyCommittedSignatures =
              psbtInputs.length == signedInputs.length &&
              Iterable<int>.generate(signedInputs.length).every(
                (index) => _hasOnlyCommittedSignatures(
                  signedInputs[index],
                  psbtInputs[index],
                ),
              );
          if (!sameHeader ||
              !sameInputs ||
              !sameOutputs ||
              !hasOnlyCommittedSignatures) {
            throw const FormatException(
              'Signed transaction does not match the prepared PSBT',
            );
          }

          return (
            transaction: hex.encode(signed.serialize()),
            txSize: signed.vsize(),
          );
        } finally {
          signed.dispose();
        }
      } finally {
        prepared.dispose();
      }
    } finally {
      psbt.dispose();
    }
  }

  ParsedBitcoinPolicy analyzePolicy({
    required BitcoinPolicyDescriptor wallet,
    List<BitcoinDescriptorKey> descriptorKeys = const [],
  }) {
    final parsedDescriptor = _DescriptorCodec.parsePublicTwoPathDescriptor(
      descriptor: wallet.descriptor,
      network: wallet.network,
    );
    final bdkWallet = _DescriptorCodec.createEphemeralDescriptorWallet(
      descriptor: wallet.descriptor,
      network: wallet.network,
    );
    final keyIdentityWallet = descriptorKeys.isEmpty
        ? null
        : _DescriptorCodec.createEphemeralDescriptorWallet(
            descriptor: _DescriptorCodec.descriptorForPolicyAnalysis(
              wallet.descriptor,
            ),
            network: wallet.network,
          );
    try {
      final external = bdkWallet.policies(keychain: bdk.KeychainKind.external_);
      final internal = bdkWallet.policies(keychain: bdk.KeychainKind.internal);
      final externalKeyIdentities =
          keyIdentityWallet?.policies(keychain: bdk.KeychainKind.external_) ??
          external;
      final internalKeyIdentities =
          keyIdentityWallet?.policies(keychain: bdk.KeychainKind.internal) ??
          internal;
      if (external == null ||
          internal == null ||
          externalKeyIdentities == null ||
          internalKeyIdentities == null) {
        throw StateError('Wallet descriptor has no spend policy');
      }

      return _PolicyMapper.fromBdk(
        external: external,
        internal: internal,
        externalKeyIdentities: externalKeyIdentities,
        internalKeyIdentities: internalKeyIdentities,
        descriptorKeys: descriptorKeys,
        unspendablePolicyKeyIdentifiers:
            parsedDescriptor.unspendablePolicyKeyIdentifiers,
        isTaproot: parsedDescriptor.externalDescriptor.startsWith('tr('),
      );
    } finally {
      keyIdentityWallet?.dispose();
      bdkWallet.dispose();
    }
  }

  BitcoinPsbtInspection inspectPsbt(
    String psbtBase64, {
    required BitcoinPolicyDescriptor wallet,
    required Set<String> walletFingerprints,
    OwnershipIndex? ownershipIndex,
  }) {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final transaction = psbt.extractTx();
      try {
        final transactionInputs = transaction.input();
        final transactionOutputs = transaction.output();
        final psbtInputs = psbt.input();
        final psbtOutputs = psbt.output();
        if (transactionInputs.length != psbtInputs.length ||
            transactionOutputs.length != psbtOutputs.length) {
          throw const InvalidBitcoinPsbtException();
        }
        _validatePartialSignatures(
          psbtBase64,
          inputs: psbtInputs,
          previousOutputs: [
            for (final input in transactionInputs) input.previousOutput,
          ],
        );

        final descriptorWallet =
            _DescriptorCodec.createEphemeralDescriptorWallet(
              descriptor: wallet.descriptor,
              network: wallet.network,
            );
        try {
          final normalizedWalletFingerprints = walletFingerprints
              .map((fingerprint) => fingerprint.toLowerCase())
              .toSet();
          final inputs = <BitcoinPsbtInputReviewRecord>[];
          for (final (index, input) in psbtInputs.indexed) {
            final previousOutput = transactionInputs[index].previousOutput;
            final utxo = _inputUtxo(input, previousOutput);
            final ownership = _descriptorOwnership(
              descriptorWallet,
              ownership: ownershipIndex,
              script: utxo.scriptPubkey,
              keySources: [
                ...input.bip32Derivation.values,
                ...input.tapKeyOrigins.values.map((origin) => origin.keySource),
              ],
            );
            if (ownership == null) {
              throw const BitcoinPsbtWalletMismatchException();
            }

            final originKeySources = [
              for (final entry in input.bip32Derivation.entries)
                (
                  publicKey: entry.key.toString().toLowerCase(),
                  fingerprint: entry.value.fingerprint.toLowerCase(),
                  derivationPath: entry.value.path.toString(),
                  isXOnly: false,
                  tapLeafHash: null,
                ),
              for (final entry in input.tapKeyOrigins.entries)
                for (final leafHash
                    in entry.value.tapLeafHashes.isEmpty
                        ? const <String?>[null]
                        : entry.value.tapLeafHashes)
                  (
                    publicKey: entry.key.toLowerCase(),
                    fingerprint: entry.value.keySource.fingerprint
                        .toLowerCase(),
                    derivationPath: entry.value.keySource.path.toString(),
                    isXOnly: true,
                    tapLeafHash: leafHash?.toLowerCase(),
                  ),
            ];
            final selectedTapLeafHashes = input.tapScripts.values
                .map(_tapLeafHash)
                .toSet();
            final signedKeySources = [
              for (final publicKey in input.partialSigs.keys)
                (
                  publicKey: publicKey.toString().toLowerCase(),
                  fingerprint: input.bip32Derivation[publicKey]?.fingerprint
                      .toLowerCase(),
                  derivationPath: input.bip32Derivation[publicKey]?.path
                      .toString(),
                  isXOnly: false,
                  tapLeafHash: null,
                ),
              if (input.tapKeySig != null && input.tapInternalKey != null)
                (
                  publicKey: input.tapInternalKey!.toLowerCase(),
                  fingerprint: input
                      .tapKeyOrigins[input.tapInternalKey]
                      ?.keySource
                      .fingerprint
                      .toLowerCase(),
                  derivationPath: input
                      .tapKeyOrigins[input.tapInternalKey]
                      ?.keySource
                      .path
                      .toString(),
                  isXOnly: true,
                  tapLeafHash: null,
                ),
              for (final signature in input.tapScriptSigs.keys)
                (
                  publicKey: signature.xonlyPubkey.toLowerCase(),
                  fingerprint: input
                      .tapKeyOrigins[signature.xonlyPubkey]
                      ?.keySource
                      .fingerprint
                      .toLowerCase(),
                  derivationPath: input
                      .tapKeyOrigins[signature.xonlyPubkey]
                      ?.keySource
                      .path
                      .toString(),
                  isXOnly: true,
                  tapLeafHash: signature.tapLeafHash.toLowerCase(),
                ),
            ];
            inputs.add((
              amountSat: BigInt.from(utxo.value.toSat()),
              keychain: ownership.keychain == Keychain.external
                  ? Keychain.external
                  : Keychain.internal,
              originKeySources: originKeySources,
              outpoint: '${previousOutput.txid}:${previousOutput.vout}',
              satisfiedPreimageKeys: _satisfiedPreimageKeys(input),
              sequence: transactionInputs[index].sequence,
              signedKeySources: signedKeySources,
              tapLeafHashes: Set.unmodifiable(selectedTapLeafHashes),
            ));
          }

          final outputs = <BitcoinPsbtOutputReviewRecord>[];
          for (final (index, txOut) in transactionOutputs.indexed) {
            final output = psbtOutputs[index];
            final ownership = _descriptorOwnership(
              descriptorWallet,
              ownership: ownershipIndex,
              script: txOut.scriptPubkey,
              keySources: [
                ...output.bip32Derivation.values,
                ...output.tapKeyOrigins.values.map(
                  (origin) => origin.keySource,
                ),
              ],
            );
            final originFingerprints = [
              ...output.bip32Derivation.values,
              ...output.tapKeyOrigins.values.map((origin) => origin.keySource),
            ].map((source) => source.fingerprint.toLowerCase()).toSet();
            if (ownership == null &&
                originFingerprints
                    .intersection(normalizedWalletFingerprints)
                    .isNotEmpty) {
              throw const BitcoinPsbtWalletMismatchException();
            }
            outputs.add((
              address: _addressFromScript(
                txOut.scriptPubkey,
                network: wallet.network,
              ),
              amountSat: BigInt.from(txOut.value.toSat()),
              index: index,
              isWalletOwned: ownership != null,
              scriptHex: hex.encode(txOut.scriptPubkey.toBytes()),
            ));
          }

          return BitcoinPsbtInspection(
            transactionId: transaction.computeTxid().toString(),
            inputs: inputs,
            outputs: outputs,
            feeSat: BigInt.from(psbt.fee()),
            estimatedTransactionVsize: _completedTransactionVsize(
              transaction: transaction,
              inputs: psbtInputs,
              inputKeychains: inputs
                  .map(
                    (input) => input.keychain == Keychain.external
                        ? Keychain.external
                        : Keychain.internal,
                  )
                  .toList(),
              wallet: wallet,
            ),
            isFinalized: psbtInputs.every(_isFinalizedInput),
            lockTime: transaction.lockTime(),
            version: transaction.version(),
          );
        } finally {
          descriptorWallet.dispose();
        }
      } finally {
        transaction.dispose();
      }
    } on bdk.MissingInputValueExtractTxException {
      throw const BitcoinPsbtMissingUtxoException();
    } finally {
      psbt.dispose();
    }
  }

  ({String psbt, bool isFinalized}) completePsbtSigning({
    required String originalPsbt,
    required String signedPsbt,
    bool tryFinalize = true,
  }) {
    final psbt = _parsePsbt(signedPsbt);
    try {
      final signed = psbt.input().every(_isFinalizedInput)
          ? (psbt: psbt.serialize(), isFinalized: true)
          : tryFinalize
          ? _finalizeCompletePsbt(psbt)
          : (psbt: psbt.serialize(), isFinalized: false);
      final normalized = _removeFixedBip341NumsKeyOrigins(
        signed.psbt,
        inputs: psbt.input(),
        outputs: psbt.output(),
      );
      return (
        psbt: signed.isFinalized
            ? normalized
            : _restoreSelectedTaprootMetadata(
                originalPsbtBase64: originalPsbt,
                signedPsbtBase64: normalized,
              ),
        isFinalized: signed.isFinalized,
      );
    } finally {
      psbt.dispose();
    }
  }

  String combinePsbts({required String first, required String second}) {
    final firstPsbt = _parsePsbt(first);
    try {
      final secondPsbt = _parsePsbt(second);
      try {
        final combined = firstPsbt.combine(other: secondPsbt);
        try {
          return combined.serialize();
        } finally {
          combined.dispose();
        }
      } finally {
        secondPsbt.dispose();
      }
    } finally {
      firstPsbt.dispose();
    }
  }

  String validateExternalPartialPsbt({
    required String currentPsbtBase64,
    required String signedPsbtBase64,
  }) {
    final current = _parsePsbt(currentPsbtBase64);
    try {
      final signed = _parsePsbt(signedPsbtBase64);
      try {
        final currentInputs = current.input();
        final signedInputs = signed.input();
        if (currentInputs.length != signedInputs.length ||
            signedInputs.any(
              (input) =>
                  input.finalScriptSig != null ||
                  input.finalScriptWitness != null,
            )) {
          throw const InvalidBitcoinPsbtException();
        }

        var hasNewSignature = false;
        for (final (index, input) in signedInputs.indexed) {
          final currentInput = currentInputs[index];
          if (input.tapInternalKey != currentInput.tapInternalKey ||
              input.tapMerkleRoot != currentInput.tapMerkleRoot ||
              !setEquals(
                _tapScriptIdentifiers(input),
                _tapScriptIdentifiers(currentInput),
              )) {
            throw const InvalidBitcoinPsbtException();
          }
          final allowedTaprootSpendModes = _taprootSpendModes(currentInput);
          if ((input.tapKeySig != null &&
                  !allowedTaprootSpendModes.contains(
                    _TaprootSpendMode.keyPath,
                  )) ||
              (input.tapScriptSigs.isNotEmpty &&
                  !allowedTaprootSpendModes.contains(
                    _TaprootSpendMode.scriptPath,
                  ))) {
            throw const InvalidBitcoinPsbtException();
          }
          for (final entry in input.partialSigs.entries) {
            final signature = entry.value;
            if (signature.isEmpty || signature.last != 0x01) {
              throw const BitcoinPsbtUnsupportedSighashException();
            }
            final currentSignature = currentInput.partialSigs[entry.key];
            if (currentSignature == null ||
                !listEquals(currentSignature, signature)) {
              hasNewSignature = true;
            }
          }
          final tapKeySignature = input.tapKeySig;
          if (tapKeySignature != null) {
            _validateTaprootSignatureSighash(
              tapKeySignature,
              requestedSighash: currentInput.sighashType,
            );
            final currentSignature = currentInput.tapKeySig;
            if (currentSignature == null ||
                !listEquals(currentSignature, tapKeySignature)) {
              hasNewSignature = true;
            }
          }
          for (final entry in input.tapScriptSigs.entries) {
            final currentOrigin = currentInput.tapKeyOrigins.entries
                .where(
                  (origin) =>
                      origin.key.toLowerCase() ==
                      entry.key.xonlyPubkey.toLowerCase(),
                )
                .firstOrNull
                ?.value;
            if (currentOrigin == null ||
                !currentOrigin.tapLeafHashes.any(
                  (hash) =>
                      hash.toLowerCase() == entry.key.tapLeafHash.toLowerCase(),
                )) {
              throw const InvalidBitcoinPsbtException();
            }
            _validateTaprootSignatureSighash(
              entry.value,
              requestedSighash: currentInput.sighashType,
            );
            final currentSignature = currentInput.tapScriptSigs.entries
                .where(
                  (candidate) =>
                      candidate.key.xonlyPubkey == entry.key.xonlyPubkey &&
                      candidate.key.tapLeafHash == entry.key.tapLeafHash,
                )
                .firstOrNull
                ?.value;
            if (currentSignature == null ||
                !listEquals(currentSignature, entry.value)) {
              hasNewSignature = true;
            }
          }
        }
        if (!hasNewSignature) throw const InvalidBitcoinPsbtException();
      } finally {
        signed.dispose();
      }
    } finally {
      current.dispose();
    }

    final combined = combinePsbts(
      first: currentPsbtBase64,
      second: signedPsbtBase64,
    );
    _validatePartialSignatures(combined);
    return combined;
  }

  ({String psbt, bool isFinalized}) finalizePsbt(String psbtBase64) {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final inputs = psbt.input();
      _validatePartialSignatures(psbtBase64, inputs: inputs);
      _rejectFinalizedInputs(inputs);
      return _finalizeCompletePsbt(psbt);
    } finally {
      psbt.dispose();
    }
  }

  ({String psbt, bool isFinalized}) _finalizeCompletePsbt(bdk.Psbt psbt) {
    final result = psbt.finalize();
    try {
      return result.couldFinalize
          ? (psbt: result.psbt.serialize(), isFinalized: true)
          : (psbt: psbt.serialize(), isFinalized: false);
    } finally {
      result.psbt.dispose();
    }
  }

  ({String psbt, bool signWithTapInternalKey}) preparePsbtForSigning(
    String psbtBase64, {
    OwnershipIndex? foreignInputWallet,
  }) {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final inputs = psbt.input();
      _validatePartialSignatures(
        psbtBase64,
        inputs: inputs,
        allowFinalizedTaprootInputs: foreignInputWallet != null,
      );
      if (foreignInputWallet == null) {
        _rejectFinalizedInputs(inputs);
      } else {
        _rejectFinalizedWalletInputs(psbt, inputs, foreignInputWallet);
      }
      return (
        psbt: _removeFixedBip341NumsKeyOrigins(
          psbtBase64,
          inputs: inputs,
          outputs: psbt.output(),
        ),
        signWithTapInternalKey: _shouldSignWithTapInternalKey(inputs),
      );
    } finally {
      psbt.dispose();
    }
  }
}
