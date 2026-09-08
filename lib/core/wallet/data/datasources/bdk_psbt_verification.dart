part of 'bdk_wallet_datasource.dart';

void _validatePartialSignatures(
  String psbtBase64, {
  List<bdk.Input>? inputs,
  bool allowFinalizedTaprootInputs = false,
  List<bdk.OutPoint>? previousOutputs,
}) {
  if (inputs == null && previousOutputs != null) {
    throw StateError('PSBT inputs and previous outputs must be provided');
  }
  final parsedPsbt = inputs == null || previousOutputs == null
      ? _parsePsbt(psbtBase64)
      : null;
  final transaction = previousOutputs == null ? parsedPsbt!.extractTx() : null;
  try {
    final bdkInputs = inputs ?? parsedPsbt!.input();
    final outpoints =
        previousOutputs ??
        [for (final input in transaction!.input()) input.previousOutput];
    if (bdkInputs.length != outpoints.length) {
      throw const InvalidBitcoinPsbtException();
    }
    final finalizedInputIndexes = [
      for (final (index, input) in bdkInputs.indexed)
        if (_isFinalizedInput(input)) index,
    ];
    if (finalizedInputIndexes.isNotEmpty) {
      final finalizedPsbt = parsedPsbt ?? _parsePsbt(psbtBase64);
      try {
        final transaction = finalizedPsbt.extractTx();
        try {
          final transactionInputs = transaction.input();
          if (transactionInputs.length != bdkInputs.length) {
            throw const InvalidBitcoinPsbtException();
          }
          for (final index in finalizedInputIndexes) {
            _validateFinalizedInputSignatures(
              transactionInputs[index],
              bdkInputs[index],
              allowTaproot: allowFinalizedTaprootInputs,
            );
          }
        } finally {
          transaction.dispose();
        }
      } finally {
        if (!identical(finalizedPsbt, parsedPsbt)) finalizedPsbt.dispose();
      }
    }
    for (final (index, input) in bdkInputs.indexed) {
      _validateSighash(
        input.sighashType,
        isTaproot: _isTaprootPsbtInput(input, outpoints[index]),
      );
    }
    final hasSignatures = bdkInputs.any(
      (input) =>
          input.partialSigs.isNotEmpty ||
          input.tapKeySig != null ||
          input.tapScriptSigs.isNotEmpty,
    );
    final hasTaprootScripts = bdkInputs.any(
      (input) => input.tapScripts.isNotEmpty,
    );
    if (!hasSignatures && !hasTaprootScripts) return;

    final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
    final builder = bitcoin_base.PsbtBuilder.fromPsbt(psbt);
    final txInputs = builder.txInputs();
    if (txInputs.length != bdkInputs.length) {
      throw const InvalidBitcoinPsbtException();
    }
    for (final (index, input) in bdkInputs.indexed) {
      if (input.tapScripts.isEmpty) continue;
      final inputInfo = bitcoin_base.PsbtUtils.getPsbtInputInfo(
        psbt: psbt,
        inputIndex: index,
        txInputs: txInputs,
      );
      _validateTaprootLeafScripts(
        psbt: psbt,
        index: index,
        expectedScriptPubKey: inputInfo.scriptPubKey,
      );
    }
    if (!hasSignatures) return;
    final unsignedTransaction = builder.buildUnsignedTransaction();
    for (final index in Iterable<int>.generate(txInputs.length)) {
      final bdkInput = bdkInputs[index];
      final isTaproot = _isTaprootPsbtInput(bdkInput, outpoints[index]);
      if (isTaproot &&
          (bdkInput.tapScripts.isEmpty || bdkInput.tapKeySig != null)) {
        _validateTaprootKeyPathSignature(
          psbt: psbt,
          index: index,
          input: bdkInput,
          txInputs: txInputs,
          unsignedTransaction: unsignedTransaction,
        );
        if (bdkInput.partialSigs.isNotEmpty ||
            bdkInput.tapScriptSigs.isNotEmpty) {
          throw const InvalidBitcoinPsbtException();
        }
        continue;
      }
      if (isTaproot) {
        _validateTaprootScriptPathSignatures(
          psbt: psbt,
          index: index,
          input: bdkInput,
          txInputs: txInputs,
          unsignedTransaction: unsignedTransaction,
        );
        if (bdkInput.partialSigs.isNotEmpty) {
          throw const InvalidBitcoinPsbtException();
        }
        continue;
      }
      final inputInfo = bitcoin_base.PsbtUtils.getPsbtInputInfo(
        psbt: psbt,
        inputIndex: index,
        txInputs: txInputs,
      );
      if (bdkInputs[index].tapKeySig != null ||
          bdkInputs[index].tapScriptSigs.isNotEmpty) {
        throw const InvalidBitcoinPsbtException();
      }
      final digest = bitcoin_base.PsbtUtils.generateInputTransactionDigest(
        index: index,
        unsignedTx: unsignedTransaction,
        params: inputInfo,
        tapleafHash: null,
        input: psbt.input,
        psbt: psbt,
      );
      final partialSignatures =
          psbt.input.getInputs<bitcoin_base.PsbtInputPartialSig>(
            index,
            bitcoin_base.PsbtInputTypes.partialSignature,
          ) ??
          const <bitcoin_base.PsbtInputPartialSig>[];
      final signingScript = inputInfo.isScriptSpending
          ? inputInfo.witnessScript ?? inputInfo.redeemScript
          : inputInfo.scriptPubKey;
      for (final signature in partialSignatures) {
        if (signature.signature.isEmpty || signature.signature.last != 0x01) {
          throw const BitcoinPsbtUnsupportedSighashException();
        }
        if (!_isBitcoinEcdsaSignature(
          Uint8List.fromList(signature.signature),
        )) {
          throw const InvalidBitcoinPsbtException();
        }
        if (!bitcoin_base.PsbtUtils.keyInScript(
              publicKey: signature.publicKey,
              script: signingScript,
              type: inputInfo.type,
            ) ||
            !digest.verifyEcdsaSignature(signature)) {
          throw const InvalidBitcoinPsbtException();
        }
      }
    }
  } finally {
    transaction?.dispose();
    parsedPsbt?.dispose();
  }
}

void _validateTaprootScriptPathSignatures({
  required bitcoin_base.Psbt psbt,
  required int index,
  required bdk.Input input,
  required List<bitcoin_base.TxInput> txInputs,
  required bitcoin_base.BtcTransaction unsignedTransaction,
}) {
  final inputInfo = bitcoin_base.PsbtUtils.getPsbtInputInfo(
    psbt: psbt,
    inputIndex: index,
    txInputs: txInputs,
  );
  final scriptPathSignatures =
      psbt.input.getInputs<bitcoin_base.PsbtInputTaprootScriptSpendSignature>(
        index,
        bitcoin_base.PsbtInputTypes.taprootScriptSpentSignature,
      ) ??
      const <bitcoin_base.PsbtInputTaprootScriptSpendSignature>[];
  for (final signature in scriptPathSignatures) {
    _validateTaprootSignatureSighash(
      signature.signature,
      requestedSighash: input.sighashType,
    );
    final origin = input.tapKeyOrigins[signature.xOnlyPubKeyHex];
    if (origin == null ||
        !origin.tapLeafHashes.any(
          (hash) => hash.toLowerCase() == hex.encode(signature.leafHash),
        )) {
      throw const InvalidBitcoinPsbtException();
    }
    try {
      final digest = bitcoin_base.PsbtUtils.generateInputTransactionDigest(
        index: index,
        unsignedTx: unsignedTransaction,
        params: inputInfo,
        tapleafHash: signature.leafHash,
        input: psbt.input,
        psbt: psbt,
        sighashType: _taprootSignatureSighash(signature.signature),
      );
      final leafScript = digest.leafScript;
      if (leafScript == null ||
          !bitcoin_base.PsbtUtils.keyInScript(
            keyStr: signature.xOnlyPubKeyHex,
            script: leafScript.leafScript.script,
            type: inputInfo.type,
          )) {
        throw const InvalidBitcoinPsbtException();
      }
      final valid = digest.getTaprootScriptSignatures([
        signature.xOnlyPubKeyHex,
      ]);
      if (!valid.any(
        (candidate) =>
            _sameBytes(candidate.leafHash, signature.leafHash) &&
            _sameBytes(candidate.signature, signature.signature),
      )) {
        throw const InvalidBitcoinPsbtException();
      }
    } on BitcoinPsbtReviewException {
      rethrow;
    } on Exception {
      throw const InvalidBitcoinPsbtException();
    }
  }
}

void _validateTaprootKeyPathSignature({
  required bitcoin_base.Psbt psbt,
  required int index,
  required bdk.Input input,
  required List<bitcoin_base.TxInput> txInputs,
  required bitcoin_base.BtcTransaction unsignedTransaction,
}) {
  final signatures =
      psbt.input.getInputs<bitcoin_base.PsbtInputTaprootKeySpendSignature>(
        index,
        bitcoin_base.PsbtInputTypes.taprootKeySpentSignature,
      ) ??
      const <bitcoin_base.PsbtInputTaprootKeySpendSignature>[];
  if (signatures.isEmpty) return;
  if (signatures.length != 1) throw const InvalidBitcoinPsbtException();

  final signature = signatures.single.signature;
  _validateTaprootSignatureSighash(
    signature,
    requestedSighash: input.sighashType,
  );
  final internalKeyHex = input.tapInternalKey;
  if (internalKeyHex == null ||
      !input.tapKeyOrigins.containsKey(internalKeyHex)) {
    throw const InvalidBitcoinPsbtException();
  }

  try {
    final internalKey = hex.decode(internalKeyHex);
    final merkleRoot = input.tapMerkleRoot == null
        ? null
        : hex.decode(input.tapMerkleRoot!);
    final scriptPubKeys = <bitcoin_base.Script>[];
    final amounts = <BigInt>[];
    for (final (inputIndex, txInput) in txInputs.indexed) {
      scriptPubKeys.add(
        bitcoin_base.PsbtUtils.getInputScriptPubKey(
          psbtInput: psbt.input,
          input: txInput,
          index: inputIndex,
        ),
      );
      amounts.add(
        bitcoin_base.PsbtUtils.getInputAmount(
          psbt: psbt,
          input: txInput,
          index: inputIndex,
        ),
      );
    }
    final address = bitcoin_base.P2trAddress.fromInternalKey(
      internalKey: internalKey,
      merkleRoot: merkleRoot,
    );
    if (address.toScriptPubKey() != scriptPubKeys[index]) {
      throw const InvalidBitcoinPsbtException();
    }
    final digest = unsignedTransaction.getTransactionTaprootDigset(
      txIndex: index,
      scriptPubKeys: scriptPubKeys,
      amounts: amounts,
      sighash: _taprootSignatureSighash(signature),
    );
    final schnorrSignature = signature.length == 65
        ? signature.sublist(0, 64)
        : signature;
    final publicKey = bitcoin_base.ECPublic.fromBytes([0x02, ...internalKey]);
    if (!publicKey.verifyBip340Signature(
      digest: digest,
      signature: schnorrSignature,
      merkleRoot: merkleRoot,
    )) {
      throw const InvalidBitcoinPsbtException();
    }
  } on BitcoinPsbtReviewException {
    rethrow;
  } on Exception {
    throw const InvalidBitcoinPsbtException();
  }
}

typedef _DescriptorOwnership = ({int index, BitcoinPolicyKeychain keychain});

bdk.Psbt _parsePsbt(String psbtBase64) {
  try {
    final normalized = normalizeBitcoinPsbt(psbtBase64);
    final psbt = bitcoin_base.Psbt.fromBase64(normalized);
    final hasMuSig2Fields = psbt.input.entries.any(
      (entries) => entries.any(
        (entry) => const {
          bitcoin_base.PsbtInputTypes.muSig2ParticipantPublicKeys,
          bitcoin_base.PsbtInputTypes.muSig2PublicNonce,
          bitcoin_base.PsbtInputTypes.muSig2ParticipantPartialSignature,
        }.contains(entry.type),
      ),
    );
    final hasMuSig2Output = psbt.output.entries.any(
      (entries) => entries.any(
        (entry) =>
            entry.type ==
            bitcoin_base.PsbtOutputTypes.muSig2ParticipantPublicKeys,
      ),
    );
    if (hasMuSig2Fields || hasMuSig2Output) {
      throw const InvalidBitcoinPsbtException();
    }
    return bdk.Psbt(psbtBase64: normalized);
  } on BitcoinPsbtReviewException {
    rethrow;
  } on Exception {
    throw const InvalidBitcoinPsbtException();
  }
}

String _retainSelectedSegwitKeyOrigins(
  String psbtBase64, {
  required List<bdk.KeychainKind> inputKeychains,
  required ({
    List<WalletDescriptorKeyModel> external,
    List<WalletDescriptorKeyModel> internal,
  })
  requiredDescriptorKeys,
}) {
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  if (psbt.input.length != inputKeychains.length) {
    throw StateError('Input keychains do not match the PSBT');
  }

  for (final (index, keychain) in inputKeychains.indexed) {
    final policyKeychain = keychain == bdk.KeychainKind.external_
        ? BitcoinPolicyKeychainModel.external
        : BitcoinPolicyKeychainModel.internal;
    final requiredKeys = keychain == bdk.KeychainKind.external_
        ? requiredDescriptorKeys.external
        : requiredDescriptorKeys.internal;
    final entries = psbt.input.entries[index].where((entry) {
      if (entry case final bitcoin_base.PsbtInputBip32DerivationPath origin) {
        return requiredKeys.any(
          (key) => walletDescriptorKeyMatches(
            key: key,
            keychain: policyKeychain,
            publicKey: hex.encode(origin.publicKey),
            fingerprint: hex.encode(origin.fingerprint),
            derivationPath: origin.path,
          ),
        );
      }
      return true;
    }).toList();
    psbt.input.replaceInput(index, entries);
  }
  return psbt.toBase64();
}

int _completedTransactionVsize({
  required bdk.Transaction transaction,
  required List<bdk.Input> inputs,
  required List<BitcoinPolicyKeychain> inputKeychains,
  required PublicBdkWalletModel wallet,
}) {
  if (inputs.length != inputKeychains.length) {
    throw const InvalidBitcoinPsbtException();
  }
  if (inputs.every(_isFinalizedInput)) return transaction.vsize();

  final networkKind = wallet.isTestnet
      ? bdk.NetworkKind.test
      : bdk.NetworkKind.main;
  final descriptors = BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: wallet.descriptor,
    isTestnet: wallet.isTestnet,
  );
  final external = bdk.Descriptor(
    descriptor: descriptors.externalDescriptor,
    networkKind: networkKind,
  );
  final internal = bdk.Descriptor(
    descriptor: descriptors.internalDescriptor,
    networkKind: networkKind,
  );
  try {
    final descriptorTypes = [
      for (final keychain in inputKeychains)
        (keychain == BitcoinPolicyKeychain.external ? external : internal)
            .descType(),
    ];
    final hasSegwitInput = descriptorTypes.any(_isSegwitDescriptor);
    final transactionAlreadyHasWitness = transaction.input().any(
      (input) => input.witness.isNotEmpty,
    );
    var completedWeight = transaction.weight();
    if (hasSegwitInput && !transactionAlreadyHasWitness) {
      // A legacy-serialized unsigned transaction has neither the SegWit
      // marker/flag nor each input's empty witness-vector count. Descriptor
      // maxWeightToSatisfy is measured from a default SegWit TxIn, which
      // already includes that empty-vector byte.
      completedWeight += 2 + inputs.length;
    }
    for (final index in Iterable<int>.generate(inputs.length)) {
      if (_isFinalizedInput(inputs[index])) continue;
      final descriptor = inputKeychains[index] == BitcoinPolicyKeychain.external
          ? external
          : internal;
      var satisfactionWeight = descriptor.maxWeightToSatisfy();
      if (!hasSegwitInput) satisfactionWeight -= 1;
      completedWeight += satisfactionWeight;
    }
    return (completedWeight + 3) ~/ 4;
  } finally {
    external.dispose();
    internal.dispose();
  }
}

bool _isFinalizedInput(bdk.Input input) =>
    input.finalScriptSig != null || input.finalScriptWitness != null;

Set<String> _satisfiedPreimageKeys(bdk.Input input) {
  final keys = <String>{
    for (final entry in input.sha256Preimages.entries)
      if (_sameBytes(
        hex.decode(entry.key),
        _preimageHash(bitcoin_base.PsbtInputSha256.fromPreImage(entry.value)),
      ))
        'sha256:${entry.key.toLowerCase()}',
    for (final entry in input.hash256Preimages.entries)
      if (_sameBytes(
        hex.decode(entry.key),
        _preimageHash(bitcoin_base.PsbtInputHash256.fromPreImage(entry.value)),
      ))
        'hash256:${entry.key.toLowerCase()}',
    for (final entry in input.ripemd160Preimages.entries)
      if (_sameBytes(
        hex.decode(entry.key),
        _preimageHash(
          bitcoin_base.PsbtInputRipemd160.fromPreImage(entry.value),
        ),
      ))
        'ripemd160:${entry.key.toLowerCase()}',
    for (final entry in input.hash160Preimages.entries)
      if (_sameBytes(
        hex.decode(entry.key),
        _preimageHash(bitcoin_base.PsbtInputHash160.fromPreImage(entry.value)),
      ))
        'hash160:${entry.key.toLowerCase()}',
  };

  for (final item in input.finalScriptWitness ?? const []) {
    if (item.length != 32) continue;
    keys.addAll(_preimageCommitmentKeys(item));
  }

  return Set.unmodifiable(keys);
}

Set<String> _preimageCommitmentKeys(List<int> preimage) => {
  'sha256:${hex.encode(_preimageHash(bitcoin_base.PsbtInputSha256.fromPreImage(preimage)))}',
  'hash256:${hex.encode(_preimageHash(bitcoin_base.PsbtInputHash256.fromPreImage(preimage)))}',
  'ripemd160:${hex.encode(_preimageHash(bitcoin_base.PsbtInputRipemd160.fromPreImage(preimage)))}',
  'hash160:${hex.encode(_preimageHash(bitcoin_base.PsbtInputHash160.fromPreImage(preimage)))}',
};

void _rejectFinalizedInputs(List<bdk.Input> inputs) {
  if (inputs.any(_isFinalizedInput)) {
    throw const InvalidBitcoinPsbtException();
  }
}

void _rejectFinalizedWalletInputs(
  bdk.Psbt psbt,
  List<bdk.Input> inputs,
  bdk.Wallet wallet,
) {
  final transaction = psbt.extractTx();
  try {
    final transactionInputs = transaction.input();
    if (transactionInputs.length != inputs.length) {
      throw const InvalidBitcoinPsbtException();
    }
    for (final (index, input) in inputs.indexed) {
      if (!_isFinalizedInput(input)) continue;
      final utxo = _inputUtxo(input, transactionInputs[index].previousOutput);
      if (wallet.isMine(script: utxo.scriptPubkey)) {
        throw const InvalidBitcoinPsbtException();
      }
    }
  } finally {
    transaction.dispose();
  }
}

bool _hasOnlyCommittedSignatures(bdk.TxIn input, bdk.Input psbtInput) {
  final signatures = _inputEcdsaSignatures(input, psbtInput);
  return signatures != null &&
      signatures.isNotEmpty &&
      signatures.every((signature) => signature.last == 0x01);
}

void _validateFinalizedInputSignatures(
  bdk.TxIn input,
  bdk.Input psbtInput, {
  bool allowTaproot = false,
}) {
  final hasUnlockingData =
      input.scriptSig.toBytes().isNotEmpty ||
      input.witness.any((item) => item.isNotEmpty);
  if (!hasUnlockingData) throw const InvalidBitcoinPsbtException();

  if (allowTaproot) {
    final signatures = _inputTaprootSignatures(input, psbtInput);
    if (signatures != null) {
      if (signatures.isEmpty) throw const InvalidBitcoinPsbtException();
      if (signatures.any(
        (signature) => signature.length == 65 && signature.last != 0x01,
      )) {
        throw const BitcoinPsbtUnsupportedSighashException();
      }
      return;
    }
  }

  final signatures = _inputEcdsaSignatures(input, psbtInput);
  if (signatures == null || signatures.isEmpty) {
    throw const InvalidBitcoinPsbtException();
  }
  if (signatures.any((signature) => signature.last != 0x01)) {
    throw const BitcoinPsbtUnsupportedSighashException();
  }
}

List<Uint8List>? _inputTaprootSignatures(bdk.TxIn input, bdk.Input psbtInput) {
  final utxo = _inputUtxo(psbtInput, input.previousOutput);
  if (!_isV1TaprootProgram(utxo.scriptPubkey.toBytes())) return null;
  final witness = input.witness.toList();
  if (witness.length >= 2 &&
      witness.last.isNotEmpty &&
      witness.last.first == 0x50) {
    witness.removeLast();
  }
  final signatureItems = witness.length <= 1
      ? witness
      : witness.sublist(0, witness.length - 2);
  return signatureItems
      .where((item) => item.length == 64 || item.length == 65)
      .toList(growable: false);
}

List<Uint8List>? _inputEcdsaSignatures(bdk.TxIn input, bdk.Input psbtInput) {
  final scriptPushes = _scriptPushes(input.scriptSig.toBytes());
  if (scriptPushes == null) return null;
  final preimages = <Uint8List>[
    ...psbtInput.sha256Preimages.values,
    ...psbtInput.hash256Preimages.values,
    ...psbtInput.ripemd160Preimages.values,
    ...psbtInput.hash160Preimages.values,
  ];
  final hashlockCommitments = _inputHashlockCommitments(
    input,
    psbtInput,
    scriptPushes,
  );
  return <Uint8List>[...input.witness, ...scriptPushes]
      .where(
        (item) =>
            _isBitcoinEcdsaSignature(item) &&
            !preimages.any((preimage) => listEquals(preimage, item)) &&
            !_matchesHashlockPreimage(item, hashlockCommitments),
      )
      .toList(growable: false);
}

List<({BitcoinHashlockType type, List<int> hash})> _inputHashlockCommitments(
  bdk.TxIn input,
  bdk.Input psbtInput,
  List<Uint8List> scriptPushes,
) {
  final scripts = <List<int>>[
    if (psbtInput.witnessScript case final script?) script.toBytes(),
    if (psbtInput.redeemScript case final script?) script.toBytes(),
    if (input.witness.length > 1) input.witness.last,
    if (scriptPushes.length > 1) scriptPushes.last,
  ];
  final commitments = <({BitcoinHashlockType type, List<int> hash})>[];
  for (final scriptBytes in scripts) {
    commitments.addAll(_scriptHashlockCommitments(scriptBytes));
  }
  return commitments;
}

List<({BitcoinHashlockType type, List<int> hash})> _scriptHashlockCommitments(
  List<int> scriptBytes,
) {
  final List<dynamic> tokens;
  try {
    tokens = bitcoin_base.Script.deserialize(bytes: scriptBytes).script;
  } on RangeError {
    throw const InvalidBitcoinPsbtException();
  }
  final commitments = <({BitcoinHashlockType type, List<int> hash})>[];
  BitcoinHashlockType? pendingType;
  for (final token in tokens) {
    final type = switch (token) {
      'OP_RIPEMD160' => BitcoinHashlockType.ripemd160,
      'OP_SHA256' => BitcoinHashlockType.sha256,
      'OP_HASH160' => BitcoinHashlockType.hash160,
      'OP_HASH256' => BitcoinHashlockType.hash256,
      _ => null,
    };
    if (type != null) {
      pendingType = type;
      continue;
    }
    final commitmentType = pendingType;
    if (commitmentType == null || token is! String) continue;
    final List<int> hash;
    try {
      hash = hex.decode(token);
    } on FormatException {
      pendingType = null;
      continue;
    }
    final expectedLength = switch (commitmentType) {
      BitcoinHashlockType.sha256 || BitcoinHashlockType.hash256 => 32,
      BitcoinHashlockType.ripemd160 || BitcoinHashlockType.hash160 => 20,
    };
    if (hash.length == expectedLength) {
      commitments.add((type: commitmentType, hash: hash));
    }
    pendingType = null;
  }
  return commitments;
}

bool _matchesHashlockPreimage(
  Uint8List item,
  List<({BitcoinHashlockType type, List<int> hash})> commitments,
) {
  for (final commitment in commitments) {
    final hash = switch (commitment.type) {
      BitcoinHashlockType.sha256 => bitcoin_base.PsbtInputSha256.fromPreImage(
        item,
      ).hash,
      BitcoinHashlockType.hash256 => bitcoin_base.PsbtInputHash256.fromPreImage(
        item,
      ).hash,
      BitcoinHashlockType.ripemd160 =>
        bitcoin_base.PsbtInputRipemd160.fromPreImage(item).hash,
      BitcoinHashlockType.hash160 => bitcoin_base.PsbtInputHash160.fromPreImage(
        item,
      ).hash,
    };
    if (_sameBytes(hash, commitment.hash)) return true;
  }
  return false;
}

bool _isBitcoinEcdsaSignature(Uint8List bytes) {
  if (bytes.length < 9 || bytes.length > 73 || bytes[0] != 0x30) return false;
  if (bytes[1] != bytes.length - 3 || bytes[2] != 0x02) return false;
  final rLength = bytes[3];
  if (rLength == 0 || 5 + rLength >= bytes.length) return false;
  final sLength = bytes[5 + rLength];
  if (rLength + sLength + 7 != bytes.length) return false;
  if ((bytes[4] & 0x80) != 0 ||
      (rLength > 1 && bytes[4] == 0 && (bytes[5] & 0x80) == 0)) {
    return false;
  }
  if (bytes[4 + rLength] != 0x02 || sLength == 0) return false;
  if ((bytes[6 + rLength] & 0x80) != 0 ||
      (sLength > 1 &&
          bytes[6 + rLength] == 0 &&
          (bytes[7 + rLength] & 0x80) == 0)) {
    return false;
  }
  return true;
}

List<Uint8List>? _scriptPushes(Uint8List script) {
  final pushes = <Uint8List>[];
  var cursor = 0;
  while (cursor < script.length) {
    final opcode = script[cursor++];
    if (opcode == 0) {
      pushes.add(Uint8List(0));
      continue;
    }
    if (opcode == 0x4f || (opcode >= 0x51 && opcode <= 0x60)) {
      // OP_1NEGATE and OP_1 through OP_16 are push-only opcodes, but cannot
      // contain a signature.
      continue;
    }
    final int length;
    if (opcode <= 75) {
      length = opcode;
    } else if (opcode == 76) {
      if (cursor >= script.length) return null;
      length = script[cursor++];
    } else if (opcode == 77) {
      if (cursor + 2 > script.length) return null;
      length = script[cursor] | (script[cursor + 1] << 8);
      cursor += 2;
    } else if (opcode == 78) {
      if (cursor + 4 > script.length) return null;
      length =
          script[cursor] |
          (script[cursor + 1] << 8) |
          (script[cursor + 2] << 16) |
          (script[cursor + 3] << 24);
      cursor += 4;
    } else {
      return null;
    }
    if (length < 0 || cursor + length > script.length) return null;
    pushes.add(Uint8List.sublistView(script, cursor, cursor + length));
    cursor += length;
  }
  return pushes;
}

bool _isSegwitDescriptor(bdk.DescriptorType type) => switch (type) {
  bdk.DescriptorType.wpkh ||
  bdk.DescriptorType.wsh ||
  bdk.DescriptorType.shWsh ||
  bdk.DescriptorType.shWpkh ||
  bdk.DescriptorType.wshSortedMulti ||
  bdk.DescriptorType.shWshSortedMulti ||
  bdk.DescriptorType.tr => true,
  bdk.DescriptorType.bare ||
  bdk.DescriptorType.sh ||
  bdk.DescriptorType.pkh ||
  bdk.DescriptorType.shSortedMulti => false,
};

bool _shouldSignWithTapInternalKey(List<bdk.Input> inputs) {
  var hasKeyPathInput = false;
  var hasScriptPathInput = false;
  for (final input in inputs.where((input) => input.tapInternalKey != null)) {
    final modes = _taprootSpendModes(input);
    if (modes.length > 1) {
      throw const BitcoinPsbtUnsupportedSpendModeException();
    }
    hasKeyPathInput |= modes.contains(_TaprootSpendMode.keyPath);
    hasScriptPathInput |= modes.contains(_TaprootSpendMode.scriptPath);
  }
  if (hasKeyPathInput && hasScriptPathInput) {
    // TODO(taproot): Configure internal-key signing per input once bdk-ffi
    // exposes that control instead of one PSBT-wide signing option.
    throw const BitcoinPsbtUnsupportedSpendModeException();
  }
  return hasKeyPathInput;
}

enum _TaprootSpendMode { keyPath, scriptPath }

Set<_TaprootSpendMode> _taprootSpendModes(bdk.Input input) {
  final internalKey = input.tapInternalKey?.toLowerCase();
  final hasInternalKeyOrigin =
      internalKey != null &&
      internalKey != _bip341NumsXOnlyKey &&
      input.tapKeyOrigins.entries.any(
        (origin) =>
            origin.key.toLowerCase() == internalKey &&
            origin.value.tapLeafHashes.isEmpty,
      );
  final hasScriptPathOrigin = input.tapKeyOrigins.values.any(
    (origin) => origin.tapLeafHashes.isNotEmpty,
  );
  return {
    if (hasInternalKeyOrigin) _TaprootSpendMode.keyPath,
    if (hasScriptPathOrigin) _TaprootSpendMode.scriptPath,
  };
}

void _validateTaprootLeafScripts({
  required bitcoin_base.Psbt psbt,
  required int index,
  required bitcoin_base.Script expectedScriptPubKey,
}) {
  final leaves =
      psbt.input.getInputs<bitcoin_base.PsbtInputTaprootLeafScript>(
        index,
        bitcoin_base.PsbtInputTypes.taprootLeafScript,
      ) ??
      const <bitcoin_base.PsbtInputTaprootLeafScript>[];
  for (final leaf in leaves) {
    try {
      final control = bitcoin_base.TaprootControlBlock.deserialize(
        leaf.controllBlock,
      );
      if ((control.leafVersion & 0xfe) != leaf.leafVersion) {
        throw const InvalidBitcoinPsbtException();
      }
      var merkleRoot = leaf.leafScript.hash();
      for (var offset = 0; offset < control.merklePath.length; offset += 32) {
        merkleRoot = bitcoin_base.TaprootUtils.tapbranchTaggedHash(
          merkleRoot,
          control.merklePath.sublist(offset, offset + 32),
        );
      }
      final tweakedKey = bitcoin_base.TaprootUtils.tweakPublicKey(
        control.xOnly,
        merkleRoot: merkleRoot,
      ).toBytes();
      final expected = bitcoin_base.P2trAddress.fromInternalKey(
        internalKey: control.xOnly,
        merkleRoot: merkleRoot,
      ).toScriptPubKey();
      if ((tweakedKey.first & 1) != (control.leafVersion & 1) ||
          expected != expectedScriptPubKey) {
        throw const InvalidBitcoinPsbtException();
      }
    } on BitcoinPsbtReviewException {
      rethrow;
    } on Exception {
      throw const InvalidBitcoinPsbtException();
    }
  }
}

String _tapLeafHash(bdk.TapScriptEntry entry) {
  final script = bitcoin_base.Script.deserialize(bytes: entry.script.toBytes());
  return hex.encode(
    bitcoin_base.TaprootUtils.tapleafTaggedHash(
      script: script,
      leafVersion: entry.leafVersion,
    ),
  );
}

Set<String> _tapScriptIdentifiers(bdk.Input input) => {
  for (final entry in input.tapScripts.entries)
    '${hex.encode(entry.key.internalKey)}:'
        '${entry.key.merkleBranch.map((hash) => hash.toLowerCase()).join(',')}:'
        '${entry.key.outputKeyParity}:${entry.key.leafVersion}:'
        '${_tapLeafHash(entry.value)}',
};

const _bip341NumsXOnlyKey =
    '50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';

String _removeFixedBip341NumsKeyOrigins(
  String psbtBase64, {
  required List<bdk.Input> inputs,
  required List<bdk.Output> outputs,
}) {
  final affectedInputIndexes = {
    for (final (index, input) in inputs.indexed)
      if (input.tapInternalKey?.toLowerCase() == _bip341NumsXOnlyKey &&
          input.tapKeyOrigins.entries.any(
            (origin) =>
                origin.key.toLowerCase() == _bip341NumsXOnlyKey &&
                origin.value.tapLeafHashes.isEmpty,
          ))
        index,
  };
  final affectedOutputIndexes = {
    for (final (index, output) in outputs.indexed)
      if (output.tapInternalKey?.toLowerCase() == _bip341NumsXOnlyKey &&
          output.tapKeyOrigins.entries.any(
            (origin) =>
                origin.key.toLowerCase() == _bip341NumsXOnlyKey &&
                origin.value.tapLeafHashes.isEmpty,
          ))
        index,
  };
  if (affectedInputIndexes.isEmpty && affectedOutputIndexes.isEmpty) {
    return psbtBase64;
  }

  // rust-miniscript emits a synthetic Taproot key origin for raw no-origin
  // keys (rust-bitcoin/rust-miniscript#998). A fixed BIP341 NUMS key has no
  // signing derivation, so omit only that metadata entry.
  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  for (final index in affectedInputIndexes) {
    final entries = psbt.input.entries[index].where((entry) {
      if (entry
          case final bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath
              derivation) {
        return derivation.leavesHashes.isNotEmpty ||
            hex.encode(derivation.xOnlyPubKey) != _bip341NumsXOnlyKey;
      }
      return true;
    }).toList();
    psbt.input.replaceInput(index, entries);
  }
  for (final index in affectedOutputIndexes) {
    final entries = psbt.output.entries[index].where((entry) {
      if (entry
          case final bitcoin_base.PsbtOutputTaprootKeyBip32DerivationPath
              derivation) {
        return derivation.leavesHashes.isNotEmpty ||
            hex.encode(derivation.xOnlyPubKey) != _bip341NumsXOnlyKey;
      }
      return true;
    }).toList();
    psbt.output.replaceOutput(index, entries);
  }
  return psbt.toBase64();
}

String _restoreSelectedTaprootMetadata({
  required String originalPsbtBase64,
  required String signedPsbtBase64,
}) {
  final original = bitcoin_base.Psbt.fromBase64(originalPsbtBase64);
  final signed = bitcoin_base.Psbt.fromBase64(signedPsbtBase64);
  if (original.input.entries.length != signed.input.entries.length) {
    throw StateError('Signed PSBT input count changed');
  }
  for (final (index, originalEntries) in original.input.entries.indexed) {
    final selectedMetadata = originalEntries.where(
      (entry) =>
          entry.type == bitcoin_base.PsbtInputTypes.taprootLeafScript ||
          entry.type == bitcoin_base.PsbtInputTypes.taprootBip32Derivation,
    );
    final signedEntries =
        signed.input.entries[index]
            .where(
              (entry) =>
                  entry.type != bitcoin_base.PsbtInputTypes.taprootLeafScript &&
                  entry.type !=
                      bitcoin_base.PsbtInputTypes.taprootBip32Derivation,
            )
            .toList()
          ..addAll(selectedMetadata);
    signed.input.replaceInput(index, signedEntries);
  }
  return signed.toBase64();
}

String _retainSelectedTaprootSpendPaths(
  String psbtBase64, {
  required List<bdk.Input> inputs,
  required List<bdk.KeychainKind> inputKeychains,
  required ({
    List<WalletDescriptorKeyModel> external,
    List<WalletDescriptorKeyModel> internal,
  })
  requiredDescriptorKeys,
}) {
  if (inputs.length != inputKeychains.length) {
    throw StateError('Taproot input keychains do not match the PSBT');
  }
  final selections = [
    for (final (index, input) in inputs.indexed)
      _selectedTaprootSpendPath(
        input,
        keychain: inputKeychains[index] == bdk.KeychainKind.external_
            ? BitcoinPolicyKeychainModel.external
            : BitcoinPolicyKeychainModel.internal,
        requiredKeys: inputKeychains[index] == bdk.KeychainKind.external_
            ? requiredDescriptorKeys.external
            : requiredDescriptorKeys.internal,
      ),
  ];
  if (selections.every((selection) => !selection.shouldFilterScripts)) {
    return psbtBase64;
  }

  final psbt = bitcoin_base.Psbt.fromBase64(psbtBase64);
  for (final (index, selection) in selections.indexed) {
    if (!selection.shouldFilterScripts) continue;
    final leafHash = selection.leafHash;
    final keychain = inputKeychains[index] == bdk.KeychainKind.external_
        ? BitcoinPolicyKeychainModel.external
        : BitcoinPolicyKeychainModel.internal;
    final requiredKeys = inputKeychains[index] == bdk.KeychainKind.external_
        ? requiredDescriptorKeys.external
        : requiredDescriptorKeys.internal;
    final entries = <bitcoin_base.PsbtInputData>[];
    for (final entry in psbt.input.entries[index]) {
      if (entry.type == bitcoin_base.PsbtInputTypes.taprootLeafScript) {
        continue;
      }
      if (entry
          case final bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath
              derivation) {
        if (leafHash == null) {
          if (hex.encode(derivation.xOnlyPubKey) ==
              inputs[index].tapInternalKey?.toLowerCase()) {
            entries.add(
              bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath(
                xOnlyPubKey: derivation.xOnlyPubKey,
                leavesHashes: const [],
                fingerprint: derivation.fingerprint,
                indexes: derivation.indexes,
              ),
            );
          }
          continue;
        }
        final matchingLeafHashes = derivation.leavesHashes
            .where((hash) => hex.encode(hash) == leafHash)
            .toList();
        final origin =
            inputs[index].tapKeyOrigins[hex.encode(derivation.xOnlyPubKey)];
        if (matchingLeafHashes.isNotEmpty &&
            origin != null &&
            requiredKeys.any(
              (key) => _tapOriginMatchesDescriptorKey(
                MapEntry(hex.encode(derivation.xOnlyPubKey), origin),
                key,
                keychain: keychain,
              ),
            )) {
          entries.add(
            bitcoin_base.PsbtInputTaprootKeyBip32DerivationPath(
              xOnlyPubKey: derivation.xOnlyPubKey,
              leavesHashes: matchingLeafHashes,
              fingerprint: derivation.fingerprint,
              indexes: derivation.indexes,
            ),
          );
        }
        continue;
      }
      entries.add(entry);
    }
    if (leafHash != null) {
      final leaves =
          psbt.input.getInputs<bitcoin_base.PsbtInputTaprootLeafScript>(
            index,
            bitcoin_base.PsbtInputTypes.taprootLeafScript,
          ) ??
          const <bitcoin_base.PsbtInputTaprootLeafScript>[];
      final selected = leaves.singleWhere(
        (leaf) => hex.encode(leaf.leafScript.hash()) == leafHash,
        orElse: () => throw StateError('Selected Taproot leaf is missing'),
      );
      entries.add(selected);
    }
    psbt.input.replaceInput(index, entries);
  }
  return psbt.toBase64();
}

({bool shouldFilterScripts, String? leafHash}) _selectedTaprootSpendPath(
  bdk.Input input, {
  required BitcoinPolicyKeychainModel keychain,
  required List<WalletDescriptorKeyModel> requiredKeys,
}) {
  if (input.tapInternalKey == null || input.tapScripts.isEmpty) {
    return (shouldFilterScripts: false, leafHash: null);
  }
  if (requiredKeys.isEmpty) {
    if (input.tapScripts.length == 1) {
      return (
        shouldFilterScripts: true,
        leafHash: _tapLeafHash(input.tapScripts.values.single),
      );
    }
    // TODO(taproot): Map keyless policy nodes to exact TapLeafHash values once
    // bdk-ffi exposes policy-to-TapLeafHash mapping.
    throw const UnsupportedBitcoinPolicyPathException();
  }

  final candidates = <String>{};
  for (final entry in input.tapScripts.entries) {
    final leafHash = _tapLeafHash(entry.value);
    final containsEveryRequiredKey = requiredKeys.every(
      (key) => input.tapKeyOrigins.entries.any(
        (origin) =>
            origin.value.tapLeafHashes.any(
              (hash) => hash.toLowerCase() == leafHash,
            ) &&
            _tapOriginMatchesDescriptorKey(origin, key, keychain: keychain),
      ),
    );
    if (containsEveryRequiredKey) candidates.add(leafHash);
  }

  final internalOrigin = input.tapKeyOrigins.entries.where(
    (origin) => origin.key.toLowerCase() == input.tapInternalKey!.toLowerCase(),
  );
  final isKeyPath =
      internalOrigin.length == 1 &&
      requiredKeys.every(
        (key) => _tapOriginMatchesDescriptorKey(
          internalOrigin.single,
          key,
          keychain: keychain,
        ),
      );
  if (isKeyPath && candidates.isEmpty) {
    return (shouldFilterScripts: true, leafHash: null);
  }
  if (!isKeyPath && candidates.length == 1) {
    return (shouldFilterScripts: true, leafHash: candidates.single);
  }
  // TODO(taproot): Support separate Tapleaves using the same descriptor keys
  // once bdk-ffi exposes exact policy-to-TapLeafHash mapping and signing for a
  // specific leaf. Until then, reject these paths to avoid signing the wrong one.
  throw const UnsupportedBitcoinPolicyPathException();
}

bool _tapOriginMatchesDescriptorKey(
  MapEntry<String, bdk.TapKeyOrigin> origin,
  WalletDescriptorKeyModel key, {
  required BitcoinPolicyKeychainModel keychain,
}) => walletDescriptorKeyMatches(
  key: key,
  publicKey: origin.key,
  fingerprint: origin.value.keySource.fingerprint,
  derivationPath: origin.value.keySource.path.toString(),
  keychain: keychain,
  isXOnly: true,
);

bdk.TxOut _inputUtxo(bdk.Input input, bdk.OutPoint previousOutput) {
  final witnessUtxo = input.witnessUtxo;
  final previousTransaction = input.nonWitnessUtxo;
  if (previousTransaction != null) {
    if (previousTransaction.computeTxid().toString() !=
        previousOutput.txid.toString()) {
      throw const InvalidBitcoinPsbtException();
    }
    final outputs = previousTransaction.output();
    if (previousOutput.vout >= outputs.length) {
      throw const BitcoinPsbtMissingUtxoException();
    }
    final previousTxOut = outputs[previousOutput.vout];
    if (witnessUtxo != null &&
        (witnessUtxo.value.toSat() != previousTxOut.value.toSat() ||
            !_sameBytes(
              witnessUtxo.scriptPubkey.toBytes(),
              previousTxOut.scriptPubkey.toBytes(),
            ))) {
      throw const InvalidBitcoinPsbtException();
    }
    return previousTxOut;
  }

  if (witnessUtxo == null) {
    throw const BitcoinPsbtMissingUtxoException();
  }
  final script = witnessUtxo.scriptPubkey.toBytes();
  if (!_isWitnessProgram(script) && !_isNestedSegwitInput(input, script)) {
    throw const BitcoinPsbtMissingUtxoException();
  }
  return witnessUtxo;
}

bool _isWitnessProgram(List<int> script) =>
    script.length >= 4 &&
    (script.first == 0 || script.first == 0x51) &&
    script[1] + 2 == script.length;

bool _isV0WitnessProgram(List<int> script) =>
    script.length >= 4 &&
    script.first == 0 &&
    (script[1] == 20 || script[1] == 32) &&
    script[1] + 2 == script.length;

bool _isV1TaprootProgram(List<int> script) =>
    script.length == 34 && script[0] == 0x51 && script[1] == 32;

bool _isNestedSegwitInput(bdk.Input input, List<int> scriptPubkey) {
  if (scriptPubkey.length != 23 ||
      scriptPubkey[0] != 0xa9 ||
      scriptPubkey[1] != 0x14 ||
      scriptPubkey.last != 0x87) {
    return false;
  }
  final finalScriptSig = input.finalScriptSig;
  final redeemScript = finalScriptSig == null
      ? input.redeemScript?.toBytes()
      : switch (_scriptPushes(finalScriptSig.toBytes())) {
          [final redeemScript] => redeemScript,
          _ => null,
        };
  if (redeemScript == null || !_isV0WitnessProgram(redeemScript)) {
    return false;
  }
  final redeemHash = bitcoin_base.BitcoinAddressUtils.scriptToHash160Bytes(
    bitcoin_base.Script.deserialize(bytes: redeemScript),
  );
  return _sameBytes(redeemHash, scriptPubkey.sublist(2, 22));
}

void _validateSighash(String? sighashType, {required bool isTaproot}) {
  if (sighashType == null) return;
  final normalized = sighashType.toUpperCase().replaceFirst('SIGHASH_', '');
  final supported = isTaproot
      ? normalized == 'DEFAULT' ||
            normalized == '0' ||
            normalized == 'ALL' ||
            normalized == '1'
      : normalized == 'ALL' || normalized == '1';
  if (!supported) {
    throw const BitcoinPsbtUnsupportedSighashException();
  }
}

bool _isTaprootPsbtInput(bdk.Input input, bdk.OutPoint previousOutput) {
  final script = _inputUtxo(input, previousOutput).scriptPubkey.toBytes();
  return script.length == 34 && script[0] == 0x51 && script[1] == 0x20;
}

void _validateTaprootSignatureSighash(
  List<int> signature, {
  String? requestedSighash,
}) {
  final signatureSighash = switch (signature.length) {
    64 => 0,
    65 when signature.last == 0x01 => 1,
    _ => throw const BitcoinPsbtUnsupportedSighashException(),
  };
  final requested = _taprootRequestedSighash(requestedSighash);
  if (requested != null && signatureSighash != requested) {
    throw const BitcoinPsbtUnsupportedSighashException();
  }
}

int? _taprootRequestedSighash(String? sighashType) {
  if (sighashType == null) return null;
  return switch (sighashType.toUpperCase().replaceFirst('SIGHASH_', '')) {
    'DEFAULT' || '0' => 0,
    'ALL' || '1' => 1,
    _ => throw const BitcoinPsbtUnsupportedSighashException(),
  };
}

int _taprootSignatureSighash(List<int> signature) =>
    signature.length == 64 ? 0 : signature.last;

_DescriptorOwnership? _descriptorOwnership(
  bdk.Wallet wallet, {
  required bdk.Script script,
  required Iterable<bdk.KeySource> keySources,
}) {
  final tracked = wallet.derivationOfSpk(spk: script);
  if (tracked != null) {
    return (
      index: tracked.index,
      keychain: tracked.keychain == bdk.KeychainKind.external_
          ? BitcoinPolicyKeychain.external
          : BitcoinPolicyKeychain.internal,
    );
  }

  final scriptBytes = script.toBytes();
  final candidateIndices = <int>{};
  for (final source in keySources) {
    final path = source.path.toU32Vec();
    if (path.isEmpty) continue;
    final child = path.last;
    const hardenedBit = 1 << 31;
    if (child & hardenedBit != 0) continue;
    if (child > 10000000) {
      throw const InvalidBitcoinPsbtException();
    }
    candidateIndices.add(child);
  }

  for (final index in candidateIndices) {
    final external = wallet.peekAddress(
      keychain: bdk.KeychainKind.external_,
      index: index,
    );
    if (_sameBytes(external.address.scriptPubkey().toBytes(), scriptBytes)) {
      return (index: index, keychain: BitcoinPolicyKeychain.external);
    }
    final internal = wallet.peekAddress(
      keychain: bdk.KeychainKind.internal,
      index: index,
    );
    if (_sameBytes(internal.address.scriptPubkey().toBytes(), scriptBytes)) {
      return (index: index, keychain: BitcoinPolicyKeychain.internal);
    }
  }
  return null;
}

String? _addressFromScript(bdk.Script script, {required bool isTestnet}) {
  try {
    return bdk.Address.fromScript(
      script: script,
      network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    ).toString();
  } on Exception {
    return null;
  }
}

bool _sameBytes(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bitcoin_base.PsbtInputData _psbtPreimage(BitcoinPolicyPreimage preimage) {
  final bytes = hex.decode(preimage.preimageHex);
  return switch (preimage.type) {
    BitcoinHashlockType.sha256 => bitcoin_base.PsbtInputSha256.fromPreImage(
      bytes,
    ),
    BitcoinHashlockType.hash256 => bitcoin_base.PsbtInputHash256.fromPreImage(
      bytes,
    ),
    BitcoinHashlockType.ripemd160 =>
      bitcoin_base.PsbtInputRipemd160.fromPreImage(bytes),
    BitcoinHashlockType.hash160 => bitcoin_base.PsbtInputHash160.fromPreImage(
      bytes,
    ),
  };
}

List<int> _preimageHash(bitcoin_base.PsbtInputData input) => switch (input) {
  bitcoin_base.PsbtInputSha256(:final hash) ||
  bitcoin_base.PsbtInputHash256(:final hash) ||
  bitcoin_base.PsbtInputRipemd160(:final hash) ||
  bitcoin_base.PsbtInputHash160(:final hash) => hash,
  _ => throw ArgumentError.value(input, 'input'),
};
