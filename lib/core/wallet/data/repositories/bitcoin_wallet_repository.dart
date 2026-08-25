import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

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
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, Result, Sats, BitcoinTransactionRecipient;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_signing_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_psbt_review.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

class BitcoinWalletRepository implements BitcoinSendPort, BitcoinSigningPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final BdkWalletDatasource _bdkWallet;
  final FrozenWalletUtxoDatasource _frozenUtxos;
  final ElectrumServersPort? electrumServers;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
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
  @useResult
  Future<Result<String, WalletFailure>> buildPsbt({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool selectedOnly = false,
    bool? replaceByFee,
    BitcoinPolicyPath? policyPath,
  }) async {
    try {
      final metadata = await _walletMetadataDatasource.fetch(walletId);

      if (metadata == null) {
        return const Err(WalletNotFoundFailure());
      }

      if (!metadata.isBitcoin) {
        return const Err(WalletTransactionBuildFailure('Not a Bitcoin wallet'));
      }

    final wallet =
        WalletModel.publicBdk(
              descriptor: metadata.publicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

      // D7 defense in depth: a frozen coin must never be spendable. BDK's
      // documented semantics are the opposite — a manually added utxo
      // (TxBuilder.addUtxos) overrides the unspendable filter — and the
      // datasource deliberately preserves those raw semantics. Enforce the
      // app-level invariant here at the repository boundary, reading the
      // frozen store LIVE at build time, so it holds for ANY caller and
      // any staleness of the caller's earlier utxo fetch — not only for
      // callers going through PrepareBitcoinSendUsecase (which reads the
      // same store plus the payjoin-derived set; payjoin exclusion stays
      // at the usecase because it comes from another repository).
      //
      // The frozen set read here is:
      //  * merged into `unspendable`, so BDK's automatic selection can
      //    never pick a frozen coin even when the caller passed no
      //    exclusion list at all;
      //  * used to strip `selected`, so a frozen coin can't be forced in
      //    as a mandatory input either (the addUtxos override above).
      final frozenRows = await _frozenUtxos.getAllFrozen();
      final unspendableKeys = {
        for (final row in frozenRows) '${row.txId}:${row.vout}',
        for (final outpoint
            in unspendable ?? const <({String txId, int vout})>[])
          '${outpoint.txId}:${outpoint.vout}',
      };
      final mergedUnspendable = [
        for (final outpoint in {
          for (final row in frozenRows) (txId: row.txId, vout: row.vout),
          ...?unspendable,
        })
          outpoint,
      ];
      final spendableSelected = selected
          ?.where(
            (utxo) => !unspendableKeys.contains('${utxo.txId}:${utxo.vout}'),
          )
          .toList();
      if (selectedOnly && (selected == null || selected.isEmpty)) {
        return const Err(WalletSelectedInputsUnavailableFailure());
      }
      if (selected != null &&
          (spendableSelected == null ||
              spendableSelected.length != selected.length)) {
        return const Err(WalletSelectedInputsUnavailableFailure());
      }

      final psbt = await _bdkWallet.buildPsbt(
        wallet: wallet,
        recipients: recipients.map(_recipientModelFromEntity).toList(),
        networkFee: networkFee,
        // An empty merged list is equivalent to null for the datasource
        // (it gates on isNotEmpty), so always pass the merge.
        unspendable: mergedUnspendable,
        selected: spendableSelected
            ?.map((utxo) => WalletUtxoMapper.fromEntity(utxo))
            .toList(),
        selectedOnly: selectedOnly,
        // Default to RBF-enabled, matching both the datasource default and
        // BDK's own default sequence (0xFFFFFFFD). `?? false` would disable
        // RBF for any caller omitting the flag — harmless while
        // setExactSequence's result was discarded, wrong now that it works.
        replaceByFee: replaceByFee ?? true,
        policyPath: policyPath,
      );

      return Ok(psbt);
    } on SelectedBitcoinCoinsUnavailableException {
      return const Err(WalletSelectedInputsUnavailableFailure());
    } on SelectedBitcoinCoinsInsufficientException {
      return const Err(WalletInsufficientFundsFailure());
    } on InsufficientFundsException {
      return const Err(WalletInsufficientFundsFailure());
    } on NoSpendableUtxoException {
      return Err(
        selectedOnly
            ? const WalletSelectedInputsUnavailableFailure()
            : const WalletNoSpendableInputsFailure(),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Bitcoin transaction construction failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletTransactionBuildFailure());
    }
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
  }) => _guardSigning(
    () => _reviewPsbt(
      psbt,
      walletId: walletId,
      requireLocalOrigin: requireLocalOrigin,
    ),
  );

  Future<BitcoinPsbtReview> _reviewPsbt(
    String psbt, {
    required String walletId,
    bool requireLocalOrigin = true,
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

    await _validateWalletPsbtInputs(psbt: psbt, wallet: wallet);
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
  Future<bool> areAddressesOfWallet(
    List<String> addresses, {
    required String walletId,
  }) async {
    final wallet = (await _publicWalletContext(walletId)).wallet;

    final isFromWallet = await _bdkWallet.areAddressesMine(
      addresses,
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

  @override
  Future<List<Sats>> getRecipientAmounts({
    required String psbt,
    required List<BitcoinTransactionRecipient> recipients,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    final amounts = await _bdkWallet.getRecipientAmounts(
      psbt,
      recipients.map(_recipientModelFromEntity).toList(),
      isTestnet: metadata.isTestnet,
    );
    return amounts.map(Sats.fromInt).toList();
  }

  BitcoinTransactionRecipientModel _recipientModelFromEntity(
    BitcoinTransactionRecipient recipient,
  ) => switch (recipient.amountSat) {
    final amount? => BitcoinTransactionRecipientModel.fixed(
      address: recipient.address,
      fixedAmountSat: amount.value.toInt(),
    ),
    null => BitcoinTransactionRecipientModel.remainder(
      address: recipient.address,
    ),
  };

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
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
    required ElectrumConnection electrumServer,
  }) {
    return _bdkWallet.dryScan(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      isTestnet: isTestnet,
      electrumServer: electrumServer,
    );
  }

  /// Verifies the stored transaction's wallet-owned input signatures against
  /// its watch-only descriptors (GHSA-6jp4-8v48-cc5v guard); no key material
  /// is loaded. See [BdkWalletDatasource.verifyTransactionInputSignatures].
  Future<TransactionSignatureStatus> getTransactionSignatureStatus({
    required String walletId,
    required String txid,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    final wallet = WalletModel.fromMetadata(metadata);
    return _bdkWallet.verifyTransactionInputSignatures(
      txid: txid,
      wallet: wallet,
    );
  }

  Future<String> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    final signatureStatus = await getTransactionSignatureStatus(
      walletId: walletId,
      txid: txid,
    );
    switch (signatureStatus) {
      case TransactionSignatureStatus.valid:
        break;
      case TransactionSignatureStatus.invalid:
        throw ManipulatedTransactionException(
          'Input signature verification failed for the stored transaction',
        );
      case TransactionSignatureStatus.unverifiable:
        throw UnverifiableTransactionException(
          'Input signatures of the stored transaction could not be verified',
        );
    }
    final metadata = await _metadataFor(walletId);
    // Building an RBF replacement needs the wallet's UTXO set, not its
    // key: the public descriptors are enough. Signing happens after,
    // inside `secrets`.
    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

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
      );
    } else {
      await _bdkWallet.validateWalletPsbtInputs(
        psbt,
        wallet: wallet,
        frozenOutpoints: frozenOutpoints,
        replacingTxid: replacingTxid,
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
};
