import 'dart:typed_data';

import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_policy_maturity_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_psbt_review_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_wallet_policy_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_signer_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BitcoinWalletRepository implements BitcoinSendPort, BitcoinSigningPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final SeedDatasource _seed;
  final BdkWalletDatasource _bdkWallet;
  final FrozenWalletUtxoDatasource _frozenUtxos;
  final ElectrumServersPort? electrumServers;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required SeedDatasource seedDatasource,
    required BdkWalletDatasource bdkWalletDatasource,
    required FrozenWalletUtxoDatasource frozenWalletUtxoDatasource,
    this.electrumServers,
  }) : _seed = seedDatasource,
       _bdkWallet = bdkWalletDatasource,
       _frozenUtxos = frozenWalletUtxoDatasource;

  Future<({WalletMetadataModel metadata, PublicBdkWalletModel wallet})>
  _publicWalletContext(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return (
      metadata: metadata,
      wallet:
          WalletModel.publicBdk(
                descriptor: metadata.publicDescriptor,
                isTestnet: metadata.isTestnet,
                id: metadata.id,
              )
              as PublicBdkWalletModel,
    );
  }

  @override
  Future<String> buildPsbt({
    required String walletId,
    required String address,
    int? amountSat,
    required NetworkFee networkFee,
    bool? drain,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
    BitcoinPolicyPath? policyPath,
  }) async {
    final context = await _publicWalletContext(walletId);
    final wallet = context.wallet;

    // A frozen coin must never be spendable. Read the frozen store at build
    // time so the invariant holds for every caller and does not depend on an
    // earlier UTXO snapshot. Payjoin exclusions remain supplied by the use
    // case because they come from a separate repository.
    //
    // The frozen set read here is:
    //  * merged into `unspendable`, so BDK's automatic selection can
    //    never pick a frozen coin even when the caller passed no
    //    exclusion list at all;
    //  * checked against `selected` by the datasource, so a frozen coin
    //    causes manual selection to fail instead of being substituted.
    final frozenRows = await _frozenUtxos.getAllFrozen();
    final mergedUnspendable = [
      for (final outpoint in {
        for (final row in frozenRows) (txId: row.txId, vout: row.vout),
        ...?unspendable,
      })
        outpoint,
    ];
    final psbt = await _bdkWallet.buildPsbt(
      wallet: wallet,
      address: address,
      amountSat: amountSat,
      networkFee: networkFee,
      drain: drain,
      // An empty merged list is equivalent to null for the datasource
      // (it gates on isNotEmpty), so always pass the merge.
      unspendable: mergedUnspendable,
      selected: selected
          ?.map((utxo) => WalletUtxoMapper.fromEntity(utxo))
          .toList(),
      // Match BDK's default RBF sequence when callers omit the flag.
      replaceByFee: replaceByFee ?? true,
      policyPath: policyPath,
      requiredDescriptorKeys: policyPath == null
          ? null
          : (
              external: _requiredDescriptorKeys(
                context.metadata,
                policyPath.requiredExternalKeys,
              ),
              internal: _requiredDescriptorKeys(
                context.metadata,
                policyPath.requiredInternalKeys,
              ),
            ),
    );

    return psbt;
  }

  List<WalletDescriptorKeyModel> _requiredDescriptorKeys(
    WalletMetadataModel metadata,
    Set<BitcoinPolicyKey> policyKeys,
  ) {
    final descriptorKeys = metadata.signers
        .expand((signer) => signer.descriptorKeys)
        .toList();
    final matched = <WalletDescriptorKeyModel>[];
    for (final policyKey in policyKeys) {
      final matches = descriptorKeys.where(
        (key) => policyKey.matches(key.toEntity()),
      );
      if (matches.isEmpty) {
        throw StateError('Selected policy key does not match the descriptor');
      }
      for (final match in matches) {
        if (!matched.any((key) => key.id == match.id)) matched.add(match);
      }
    }
    return matched;
  }

  @override
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  signPsbt(
    String psbt, {
    required String walletId,
    bool tryFinalize = true,
    String? signerId,
  }) => _guardSigning(
    () => _signPsbt(
      psbt,
      walletId: walletId,
      tryFinalize: tryFinalize,
      signerId: signerId,
    ),
  );

  Future<({String psbt, bool isFinalized})> _signPsbt(
    String psbt, {
    required String walletId,
    bool tryFinalize = true,
    String? signerId,
    String? replacingTxid,
  }) async {
    final context = await _publicWalletContext(walletId);
    final metadata = context.metadata;
    final publicWallet = context.wallet;
    await _validateWalletPsbtInputs(
      psbt: psbt,
      wallet: publicWallet,
      replacingTxid: replacingTxid,
    );

    var descriptor = _withoutDescriptorChecksum(metadata.publicDescriptor);
    var injectedKey = false;
    final localSigners = metadata.signers.where(
      (signer) =>
          signer.signer == Signer.local &&
          (signerId == null || signer.id == signerId),
    );
    final injectedPublicKeys = <String>{};
    for (final signer in localSigners) {
      for (final key in signer.descriptorKeys) {
        final derivationPath = key.derivationPath;
        if (derivationPath == null) {
          throw StateError('Local descriptor key has no derivation path');
        }
        final seed = await _seed.get(key.masterFingerprint);
        final rootKey = _descriptorSecretKey(seed, network: metadata.network);
        try {
          final path = bdk.DerivationPath(path: derivationPath);
          try {
            final accountKey = rootKey.derive(path: path);
            try {
              final publicKey = accountKey.asPublic();
              try {
                final publicKeyString = publicKey.toString();
                final privateKeyString = accountKey.toString();
                if (!injectedPublicKeys.add(publicKeyString)) continue;
                final descriptorWithKey = descriptor.replaceAll(
                  publicKeyString,
                  privateKeyString,
                );
                if (descriptorWithKey == descriptor) {
                  throw StateError(
                    'Local descriptor key is not present in descriptors',
                  );
                }
                descriptor = descriptorWithKey;
                injectedKey = true;
              } finally {
                publicKey.dispose();
              }
            } finally {
              accountKey.dispose();
            }
          } finally {
            path.dispose();
          }
        } finally {
          rootKey.dispose();
        }
      }
    }
    if (!injectedKey) throw const BitcoinPsbtMissingLocalOriginException();

    return _bdkWallet.signPsbtWithDescriptor(
      psbt,
      descriptor: descriptor,
      isTestnet: metadata.isTestnet,
      tryFinalize: tryFinalize,
    );
  }

  @override
  Future<Result<BitcoinPsbtReview, BitcoinSigningFailure>> reviewPsbt(
    String psbt, {
    required String walletId,
    bool requireLocalOrigin = true,
    bool allowSpentWalletInputs = false,
  }) => _guardSigning(
    () => _reviewPsbt(
      psbt,
      walletId: walletId,
      requireLocalOrigin: requireLocalOrigin,
      allowSpentWalletInputs: allowSpentWalletInputs,
    ),
  );

  Future<BitcoinPsbtReview> _reviewPsbt(
    String psbt, {
    required String walletId,
    bool requireLocalOrigin = true,
    bool allowSpentWalletInputs = false,
  }) async {
    final context = await _publicWalletContext(walletId);
    final metadata = context.metadata;
    final wallet = context.wallet;
    final localSignerIds = metadata.signers
        .where((signer) => signer.signer == Signer.local)
        .map((signer) => signer.id)
        .toSet();
    if (requireLocalOrigin && localSignerIds.isEmpty) {
      throw const BitcoinPsbtMissingLocalOriginException();
    }

    await _validateWalletPsbtInputs(
      psbt: psbt,
      wallet: wallet,
      allowSpentWalletInputs: allowSpentWalletInputs,
    );
    final model = await _bdkWallet.inspectPsbt(
      psbt,
      wallet: wallet,
      walletFingerprints: metadata.signers
          .expand((signer) => signer.descriptorKeys)
          .expand((key) => [key.masterFingerprint, key.xpubFingerprint])
          .where((fingerprint) => fingerprint.isNotEmpty)
          .map((fingerprint) => fingerprint.toLowerCase())
          .toSet(),
    );
    final review = BitcoinPsbtReviewMapper.toEntity(
      model,
      descriptorKeys: metadata.signers
          .expand((signer) => signer.descriptorKeys)
          .toList(),
      localSignerIds: localSignerIds,
    );
    if (requireLocalOrigin &&
        !review.inputs.any((input) => input.hasLocalSignerOrigin)) {
      throw const BitcoinPsbtMissingLocalOriginException();
    }
    return review;
  }

  @override
  Future<Result<BitcoinWalletPolicy, BitcoinSigningFailure>> getPolicy({
    required String walletId,
  }) => _guardSigning(() => _getPolicy(walletId: walletId));

  Future<BitcoinWalletPolicy> _getPolicy({required String walletId}) async {
    final context = await _publicWalletContext(walletId);
    final metadata = context.metadata;

    return BitcoinWalletPolicyMapper.toEntity(
      _bdkWallet.analyzePolicy(
        wallet: context.wallet,
        descriptorKeys: metadata.signers
            .expand((signer) => signer.descriptorKeys)
            .toList(),
      ),
    );
  }

  @override
  Future<Result<BitcoinPolicyMaturity, BitcoinSigningFailure>>
  getPolicyMaturity({
    required String walletId,
    required bool includeTimeBasedLocks,
  }) => _guardSigning(
    () => _getPolicyMaturity(
      walletId: walletId,
      includeTimeBasedLocks: includeTimeBasedLocks,
    ),
  );

  Future<BitcoinPolicyMaturity> _getPolicyMaturity({
    required String walletId,
    required bool includeTimeBasedLocks,
  }) async {
    final context = await _publicWalletContext(walletId);
    final metadata = context.metadata;
    final wallet = context.wallet;
    final cachedModel = await _bdkWallet.getPolicyMaturity(
      wallet: wallet,
      includeTimeBasedLocks: includeTimeBasedLocks,
    );
    final servers = electrumServers;
    if (servers == null) {
      return BitcoinPolicyMaturityMapper.toEntity(cachedModel);
    }

    try {
      final model = await servers.runWithFallback(
        network: ElectrumServerNetwork.fromEnvironment(
          isTestnet: metadata.isTestnet,
          isLiquid: false,
        ),
        operation: (connection) => _bdkWallet.getPolicyMaturity(
          wallet: wallet,
          electrumServer: connection,
          includeTimeBasedLocks: includeTimeBasedLocks,
        ),
      );
      return BitcoinPolicyMaturityMapper.toEntity(model);
    } on Exception {
      // Cached height remains safe: stale data only keeps a path hidden longer.
      // Time-based paths stay unavailable until median-time-past is known.
      return BitcoinPolicyMaturityMapper.toEntity(cachedModel);
    }
  }

  @override
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  combinePsbts({
    required String currentPsbt,
    required String signedPsbt,
    required String walletId,
    bool tryFinalize = true,
  }) => _guardSigning(
    () => _combinePsbts(
      currentPsbt: currentPsbt,
      signedPsbt: signedPsbt,
      walletId: walletId,
      tryFinalize: tryFinalize,
    ),
  );

  Future<({String psbt, bool isFinalized})> _combinePsbts({
    required String currentPsbt,
    required String signedPsbt,
    required String walletId,
    bool tryFinalize = true,
  }) async {
    final context = await _publicWalletContext(walletId);
    final metadata = context.metadata;
    final wallet = context.wallet;
    _bdkWallet.validateExternalPartialPsbt(
      currentPsbtBase64: currentPsbt,
      signedPsbtBase64: signedPsbt,
    );
    final String combined;
    try {
      combined = _bdkWallet.combinePsbts(
        first: currentPsbt,
        second: signedPsbt,
      );
    } on bdk.PsbtException {
      throw const InvalidBitcoinPsbtException();
    }
    await _validateWalletPsbtInputs(psbt: combined, wallet: wallet);
    await _bdkWallet.inspectPsbt(
      combined,
      wallet: wallet,
      walletFingerprints: metadata.signers
          .expand((signer) => signer.descriptorKeys)
          .expand((key) => [key.masterFingerprint, key.xpubFingerprint])
          .where((fingerprint) => fingerprint.isNotEmpty)
          .map((fingerprint) => fingerprint.toLowerCase())
          .toSet(),
    );
    return tryFinalize
        ? _bdkWallet.finalizePsbt(combined)
        : (psbt: combined, isFinalized: false);
  }

  @override
  Future<Result<({String psbt, bool isFinalized}), BitcoinSigningFailure>>
  finalizePsbt(String psbt) =>
      _guardSigning(() async => _bdkWallet.finalizePsbt(psbt));

  @override
  Future<Result<bool, BitcoinSigningFailure>> validatePolicyPreimage(
    BitcoinPolicyPreimage preimage,
  ) => _guardSigning(() async => _bdkWallet.validatePolicyPreimage(preimage));

  @override
  Future<Result<String, BitcoinSigningFailure>> applyPolicyPreimages({
    required String psbt,
    required List<BitcoinPolicyPreimage> preimages,
  }) => _guardSigning(
    () async => _bdkWallet.applyPolicyPreimages(psbt, preimages),
  );

  @override
  Future<Result<({String transaction, int txSize}), BitcoinSigningFailure>>
  verifyFinalTransaction({required String psbt, required String transaction}) =>
      _guardSigning(() async {
        try {
          return _bdkWallet.verifyFinalTransaction(
            psbtBase64: psbt,
            transactionHex: transaction,
          );
        } on FormatException {
          throw const InvalidBitcoinPsbtException();
        } on bdk.TransactionException {
          throw const InvalidBitcoinPsbtException();
        }
      });

  Future<bool> isScriptOfWallet({
    required String walletId,
    required Uint8List script,
  }) async {
    final wallet = (await _publicWalletContext(walletId)).wallet;

    final isFromWallet = await _bdkWallet.isMine(script, wallet: wallet);

    return isFromWallet;
  }

  @override
  Future<bool> isAddressOfWallet(
    String address, {
    required String walletId,
  }) async {
    final wallet = (await _publicWalletContext(walletId)).wallet;

    final isFromWallet = await _bdkWallet.isAddressMine(
      address,
      wallet: wallet,
    );

    return isFromWallet;
  }

  @override
  Future<int> getTxSize({
    required String psbt,
    required String walletId,
  }) async {
    final wallet = (await _publicWalletContext(walletId)).wallet;
    return _bdkWallet.decodeTxSize(psbt, wallet: wallet);
  }

  Future<int> getTxFeeAmount({required String psbt}) async {
    final feeAbsolute = await _bdkWallet.getFeeAmount(psbt);
    return feeAbsolute;
  }

  Future<int> getAmountSentToAddress({
    required String psbt,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return await _bdkWallet.getAmountSentToAddress(
      psbt,
      address,
      isTestnet: metadata.isTestnet,
    );
  }

  Future<PrivateBdkWalletModel> getPrivateWallet({
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final scriptType = metadata.inferredScriptType;
    if (metadata.signers.length != 1 || scriptType == null) {
      throw StateError('Standard local single-signature wallet required');
    }
    final signer = metadata.signers.single;
    if (signer.descriptorKeys.length != 1) {
      throw StateError('Standard local single-signature wallet required');
    }
    final descriptorKey = signer.descriptorKeys.single;
    final account = scriptType.standardAccount(
      descriptorKey.derivationPath,
      metadata.network,
    );
    if (signer.signer != Signer.local ||
        account == null ||
        descriptorKey.descriptorPath != standardSingleSignatureDescriptorPath) {
      throw StateError('Standard local single-signature wallet required');
    }

    final seed = await _seed.get(descriptorKey.masterFingerprint);
    if (seed is! MnemonicSeedModel) {
      throw StateError('Standard local single-signature wallet required');
    }
    final mnemonic = seed.mnemonicWords.join(' ');

    final wallet =
        WalletModel.privateBdk(
              id: metadata.id,
              mnemonic: mnemonic,
              passphrase: seed.passphrase,
              scriptType: scriptType,
              account: account,
              isTestnet: metadata.isTestnet,
            )
            as PrivateBdkWalletModel;
    return wallet;
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required List<int> entropy,
    required String passphrase,
    required ScriptType scriptType,
    required bool isTestnet,
    required ElectrumConnection electrumServer,
  }) {
    return _bdkWallet.dryScan(
      entropy: entropy,
      passphrase: passphrase,
      scriptType: scriptType,
      isTestnet: isTestnet,
      electrumServer: electrumServer,
    );
  }

  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    final wallet = await getPrivateWallet(walletId: walletId);
    final psbt = await _bdkWallet.createUnsignedReplaceByFeePsbt(
      wallet: wallet,
      txid: txid,
      feeRate: newFeeRate,
    );
    final signed = await _signPsbt(
      psbt,
      walletId: walletId,
      replacingTxid: txid,
    );
    if (!signed.isFinalized) {
      throw StateError('Replacement transaction is not fully signed');
    }
    return signed.psbt;
  }

  bdk.DescriptorSecretKey _descriptorSecretKey(
    SeedModel seed, {
    required Network network,
  }) {
    if (seed is MnemonicSeedModel) {
      final mnemonic = bdk.Mnemonic.fromString(
        mnemonic: seed.mnemonicWords.join(' '),
      );
      try {
        return bdk.DescriptorSecretKey(
          networkKind: network.isTestnet
              ? bdk.NetworkKind.test
              : bdk.NetworkKind.main,
          mnemonic: mnemonic,
          password: seed.passphrase,
        );
      } finally {
        mnemonic.dispose();
      }
    }

    final xprv = Bip32Derivation.getXprvFromSeed(
      Uint8List.fromList(seed.bytes),
      network,
    );
    return bdk.DescriptorSecretKey.fromString(privateKey: xprv);
  }

  String _withoutDescriptorChecksum(String descriptor) =>
      descriptor.split('#').first;

  Future<void> _validateWalletPsbtInputs({
    required String psbt,
    required PublicBdkWalletModel wallet,
    String? replacingTxid,
    bool allowSpentWalletInputs = false,
  }) async {
    final frozenRows = await _frozenUtxos.getAllFrozen();
    final frozenOutpoints = {
      for (final row in frozenRows) '${row.txId}:${row.vout}',
    };
    if (replacingTxid == null) {
      await _bdkWallet.validateWalletPsbtInputs(
        psbt,
        wallet: wallet,
        frozenOutpoints: frozenOutpoints,
        allowSpentWalletInputs: allowSpentWalletInputs,
      );
    } else {
      await _bdkWallet.validateWalletPsbtInputs(
        psbt,
        wallet: wallet,
        frozenOutpoints: frozenOutpoints,
        replacingTxid: replacingTxid,
        allowSpentWalletInputs: allowSpentWalletInputs,
      );
    }
  }

  Future<Result<T, BitcoinSigningFailure>> _guardSigning<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return Ok(await operation());
    } on BitcoinPsbtReviewException catch (error) {
      return Err(BitcoinSigningFailure(_signingFailureKind(error)));
    } on UnsupportedBitcoinPolicyPathException {
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unsupportedPolicyPath),
      );
    } on Exception catch (error, stackTrace) {
      log.severe(
        message: 'Bitcoin signing operation failed',
        error: error,
        trace: stackTrace,
      );
      return const Err(
        BitcoinSigningFailure(BitcoinSigningFailureKind.unexpected),
      );
    }
  }
}

BitcoinSigningFailureKind _signingFailureKind(
  BitcoinPsbtReviewException exception,
) => switch (exception) {
  InvalidBitcoinPsbtException() => BitcoinSigningFailureKind.invalidPsbt,
  BitcoinPsbtWalletMismatchException() =>
    BitcoinSigningFailureKind.walletMismatch,
  BitcoinPsbtMissingLocalOriginException() =>
    BitcoinSigningFailureKind.missingLocalOrigin,
  BitcoinPsbtMissingUtxoException() => BitcoinSigningFailureKind.missingUtxo,
  BitcoinPsbtFrozenUtxoException() => BitcoinSigningFailureKind.frozenUtxo,
  BitcoinPsbtUnsupportedSighashException() =>
    BitcoinSigningFailureKind.unsupportedSighash,
  BitcoinPsbtUnsupportedSpendModeException() =>
    BitcoinSigningFailureKind.unsupportedSpendMode,
};
