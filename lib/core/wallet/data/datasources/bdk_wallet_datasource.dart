import 'dart:async';
import 'dart:math';
import 'package:bb_mobile/core/electrum/data/electrum_median_time_past.dart';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/utils/address_script_conversions.dart';
import 'package:bb_mobile/core/utils/bitcoin_signer_result.dart';
import 'package:bb_mobile/core/utils/generic_extensions.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/mappers/bitcoin_wallet_policy_mapper.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_descriptor_key_matcher.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_policy_maturity_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_psbt_review_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_wallet_policy_model.dart';
import 'package:bb_mobile/core/wallet/data/models/balance_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core/wallet/data/models/transaction_output_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_coin_selection_exception.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_psbt_review_exception.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/unsupported_bitcoin_policy_path_exception.dart';
import 'package:bitcoin_base/bitcoin_base.dart' as bitcoin_base;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart' show Outpoint;

part 'bdk_psbt_verification.dart';

extension NetworkX on Network {
  bdk.Network get bdkNetwork {
    switch (this) {
      case Network.bitcoinMainnet:
        return bdk.Network.bitcoin;
      case Network.bitcoinTestnet:
        return bdk.Network.testnet;
      default:
        throw UnsupportedBdkNetworkException('$name is not supported by BDK');
    }
  }
}

extension BdkNetworkX on bdk.Network {
  Network get network {
    if (this == bdk.Network.bitcoin) {
      return Network.bitcoinMainnet;
    } else {
      return Network.bitcoinTestnet;
    }
  }
}

class BdkWalletDatasource {
  @visibleForTesting
  final Map<String, int> syncExecutions = {};
  final Map<String, Future<void>> _activeSyncs;
  final StreamController<String> _walletSyncStartedController;
  final StreamController<String> _walletSyncFinishedController;

  BdkWalletDatasource()
    : _activeSyncs = {},
      _walletSyncStartedController = StreamController<String>.broadcast(),
      _walletSyncFinishedController = StreamController<String>.broadcast();

  Stream<String> get walletSyncStartedStream =>
      _walletSyncStartedController.stream;

  Stream<String> get walletSyncFinishedStream =>
      _walletSyncFinishedController.stream;

  bool isWalletSyncing({String? walletId}) => walletId == null
      ? _activeSyncs.isNotEmpty
      : _activeSyncs.containsKey(walletId);

  BdkTwoPathDescriptor parsePublicTwoPathDescriptor({
    required String descriptor,
    required bool isTestnet,
  }) => BdkFacade.parsePublicTwoPathDescriptor(
    descriptor: descriptor,
    isTestnet: isTestnet,
  );

  Future<BalanceModel> getBalance({required WalletModel wallet}) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final balanceInfo = bdkWallet.balance();

    final balance = BalanceModel(
      confirmedSat: BigInt.from(balanceInfo.confirmed.toSat()),
      immatureSat: BigInt.from(balanceInfo.immature.toSat()),
      trustedPendingSat: BigInt.from(balanceInfo.trustedPending.toSat()),
      untrustedPendingSat: BigInt.from(balanceInfo.untrustedPending.toSat()),
      spendableSat: BigInt.from(balanceInfo.trustedSpendable.toSat()),
      totalSat: BigInt.from(balanceInfo.total.toSat()),
    );

    return balance;
  }

  Future<void> sync({
    required WalletModel wallet,
    required ElectrumConnection electrumServer,
  }) {
    // putIfAbsent ensures only one sync starts for each wallet ID,
    //  all others await the same Future.
    // TODO: if needed, add these debugPrint to a filterable logger.debug
    // TODO: to avoid spamming the terminal with recurring prints
    // debugPrint('Sync requested for wallet: ${wallet.id}');
    return _activeSyncs.putIfAbsent(wallet.id, () async {
      try {
        // debugPrint('New sync started for wallet: ${wallet.id}');
        // Notify that the wallet is syncing through a stream for other
        // parts of the app to listen to so they can show a syncing indicator
        _walletSyncStartedController.add(wallet.id);

        // Increment the sync execution count for this wallet for testing purposes
        syncExecutions.update(wallet.id, (v) => v + 1, ifAbsent: () => 1);

        await compute(
          _performFullScan,
          _SyncParams(
            walletId: wallet.id,
            descriptor: (wallet as PublicBdkWalletModel).descriptor,
            isTestnet: wallet.isTestnet,
            electrumUrl: electrumServer.url,
            electrumSocks5: electrumServer.socks5,
            electrumStopGap: electrumServer.stopGap,
            electrumTimeout: electrumServer.effectiveTimeout,
            electrumRetry: electrumServer.retry,
            electrumValidateDomain: electrumServer.validateDomain,
            walletHexId: wallet.hexId,
            rootIsolateToken: ServicesBinding.rootIsolateToken!,
          ),
        );
        //debugPrint('Sync completed for wallet: ${wallet.id} with server ${electrumServer.url}',);
      } catch (e) {
        // debugPrint('Sync error for wallet ${wallet.id} with server ${electrumServer.url}: $e');
        rethrow;
      } finally {
        // Notify that the wallet has been synced through a stream for other
        // parts of the app to listen to
        _walletSyncFinishedController.add(wallet.id);
        // Remove the sync so future syncs can be triggered
        // Do not await this, as it is not necessary and can cause deadlocks
        // since it returns the Future from the map.
        // ignore: unawaited_futures
        _activeSyncs.remove(wallet.id);
      }
    });
  }

  Future<bool> isMine(
    Uint8List scriptBytes, {
    required WalletModel wallet,
    bdk.Wallet? bdkWallet,
  }) async {
    final w = bdkWallet ?? await BdkFacade.createWallet(wallet);
    return w.isMine(script: bdk.Script(rawOutputScript: scriptBytes));
  }

  /// Returns a synchronous `isMine` check bound to a pre-loaded bdk wallet.
  Future<bool Function(Uint8List)> createIsMineChecker({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    return (Uint8List scriptBytes) =>
        bdkWallet.isMine(script: bdk.Script(rawOutputScript: scriptBytes));
  }

  /// Returns a synchronous outpoint-ownership check bound to a pre-loaded bdk
  /// wallet.
  ///
  /// Built from `listOutput()`, not `listUnspent()` or `getUtxo()`: those only
  /// know the wallet's *unspent* outputs, so an output we owned and already
  /// spent would answer "not mine". Answering over the full set leaves the
  /// caller no gap to reason about. The set is a snapshot of the local index at
  /// creation time — cheap, no network — so bind it per operation rather than
  /// caching it across syncs.
  Future<bool Function(Outpoint)> createOutpointIsMineChecker({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final owned = <Outpoint>{
      for (final output in bdkWallet.listOutput())
        (txId: output.outpoint.txid.toString(), vout: output.outpoint.vout),
    };
    return owned.contains;
  }

  /// Returns a synchronous PSBT signer bound to a pre-loaded private bdk
  /// wallet. Uses the same sign options as [signPsbt] — in particular
  /// `allowAllSighashes: false`, since this signs the wallet's contribution
  /// to an externally-supplied transaction (a payjoin proposal).
  Future<String Function(String)> createPsbtSigner({
    required PrivateBdkWalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createPrivateWallet(wallet);
    return (String psbtBase64) {
      final psbt = _parsePsbt(psbtBase64);
      // The receiver signs its own inputs; the sender's inputs remain
      // unsigned until the proposal is returned.
      bdkWallet.sign(
        psbt: psbt,
        signOptions: bdk.SignOptions(
          trustWitnessUtxo: true,
          assumeHeight: null,
          allowAllSighashes: false,
          tryFinalize: true,
          signWithTapInternalKey: false,
          allowGrinding: true,
        ),
      );
      return psbt.serialize();
    };
  }

  Future<bool> isAddressMine(
    String address, {
    required WalletModel wallet,
    bdk.Wallet? bdkWallet,
  }) async {
    final w = bdkWallet ?? await BdkFacade.createWallet(wallet);
    final bdkAddress = bdk.Address(
      address: address,
      network: wallet.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    return w.isMine(script: bdkAddress.scriptPubkey());
  }

  Future<String> buildPsbt({
    required String address,
    required NetworkFee networkFee,
    int? amountSat,
    List<({String txId, int vout})>? unspendable,
    bool? drain,
    List<WalletUtxoModel>? selected,
    bool replaceByFee = true,
    BitcoinPolicyPath? policyPath,
    ({
      List<WalletDescriptorKeyModel> external,
      List<WalletDescriptorKeyModel> internal,
    })?
    requiredDescriptorKeys,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    bdk.TxBuilder txBuilder;

    // Get the scriptPubkey from the address
    final bdkAddress = bdk.Address(
      address: address,
      network: wallet.isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
    );
    final script = bdkAddress.scriptPubkey();

    // Check if the transaction is a drain transaction
    if (drain == true) {
      txBuilder = bdk.TxBuilder().drainWallet().drainTo(script: script);
    } else {
      if (amountSat == null) {
        throw ArgumentError('amountSat is required');
      }
      txBuilder = bdk.TxBuilder().addRecipient(
        script: script,
        amount: bdk.Amount.fromSat(satoshi: amountSat),
      );
    }

    // bdk_dart always has RBF (nSequence = 0xFFFFFFFD) enabled by default,
    // so we set the sequence to 0xFFFFFFFE if replaceByFee is explicitly set to false to disable RBF.
    if (!replaceByFee && policyPath?.requiresRelativeTimelock != true) {
      txBuilder = txBuilder.setExactSequence(nsequence: 0xFFFFFFFE);
    }

    if (policyPath != null) {
      if (policyPath.external.isNotEmpty) {
        txBuilder = txBuilder.policyPath(
          policyPath: policyPath.external,
          keychain: bdk.KeychainKind.external_,
        );
      }
      if (policyPath.internal.isNotEmpty) {
        txBuilder = txBuilder.policyPath(
          policyPath: policyPath.internal,
          keychain: bdk.KeychainKind.internal,
        );
      }
    }

    switch (networkFee) {
      case AbsoluteFee(:final sats):
        txBuilder = txBuilder.feeAbsolute(
          feeAmount: bdk.Amount.fromSat(satoshi: sats),
        );
      case RelativeFee(:final satPerKwu):
        // sat/kwu is BDK's native u64 unit, so this is a zero-rounding
        // pass-through. Using fromSatPerVb would force an int sat/vByte
        // and silently drop fractional rates (the bug fixed in #2133).
        txBuilder = txBuilder.feeRate(
          feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: satPerKwu),
        );
    }

    // Keep policy-ineligible coins out of automatic and manual coin selection.
    // Relative timelocks are per UTXO, so a wallet can have a mix of eligible
    // and ineligible coins for the same selected descriptor path.
    final unspendableByKey = {
      for (final input in unspendable ?? const <({String txId, int vout})>[])
        '${input.txId}:${input.vout}': input,
    };
    final unspents = bdkWallet.listUnspent();
    if (policyPath != null) {
      for (final utxo in unspents) {
        final key = '${utxo.outpoint.txid}:${utxo.outpoint.vout}';
        final eligible = utxo.keychain == bdk.KeychainKind.external_
            ? policyPath.eligibleExternalOutpoints
            : policyPath.eligibleInternalOutpoints;
        if (eligible != null && !eligible.contains(key)) {
          unspendableByKey[key] = (
            txId: utxo.outpoint.txid.toString(),
            vout: utxo.outpoint.vout,
          );
        }
      }
    }

    final selectedKeys = {
      for (final utxo in selected ?? const <WalletUtxoModel>[])
        '${utxo.txId}:${utxo.vout}',
    };
    final hasManualSelection = selectedKeys.isNotEmpty;
    if (hasManualSelection) {
      final unspentKeys = {
        for (final utxo in unspents)
          '${utxo.outpoint.txid}:${utxo.outpoint.vout}',
      };
      final hasDuplicateSelection = selectedKeys.length != selected!.length;
      final hasUnavailableSelection =
          hasDuplicateSelection ||
          !unspentKeys.containsAll(selectedKeys) ||
          selectedKeys.any(unspendableByKey.containsKey);
      if (hasUnavailableSelection) {
        throw SelectedBitcoinCoinsUnavailableException();
      }

      final selectedOutpoints = selected
          .map(
            (utxo) => bdk.OutPoint(
              txid: bdk.Txid.fromString(hex: utxo.txId),
              vout: utxo.vout,
            ),
          )
          .toList();
      // Apply the selection only after checking that every coin is eligible.
      txBuilder = txBuilder
          .addUtxos(outpoints: selectedOutpoints)
          .manuallySelectedOnly();
    }

    final unspendableOutPoints = unspendableByKey.values
        .map(
          (input) => bdk.OutPoint(
            txid: bdk.Txid.fromString(hex: input.txId),
            vout: input.vout,
          ),
        )
        .toList();

    // TODO: MOVE THIS TO THE TRANSACTION REPOSITORY, the repository should check the unspendable and spendable inputs
    // and build the transaction accordingly or return an error
    if (unspendableOutPoints.isNotEmpty) {
      // Check if there are unspents that are not in the unspendable set so a
      // transaction can be built. Compare by (txId, vout) value, NOT by
      // bdk.OutPoint identity: OutPoint/Txid are opaque Rust handles with no
      // `==` override, so a freshly-built OutPoint never equals listUnspent's.
      // Set.contains on the objects would always miss, leaving the all-frozen
      // case undetected (BDK would then fail with "insufficient funds" instead
      // of NoSpendableUtxoException).
      final spendableUtxos = unspents.where((utxo) {
        final key = '${utxo.outpoint.txid}:${utxo.outpoint.vout}';
        return !unspendableByKey.containsKey(key);
      }).toList();

      if (spendableUtxos.isEmpty) {
        throw NoSpendableUtxoException('All unspents are unspendable');
      }

      txBuilder = txBuilder.unspendable(unspendable: unspendableOutPoints);
    }

    late final bdk.Psbt psbt;
    try {
      psbt = txBuilder.finish(wallet: bdkWallet);
    } on bdk.InsufficientFundsCreateTxException catch (e) {
      if (hasManualSelection) {
        throw SelectedBitcoinCoinsInsufficientException();
      }
      throw InsufficientFundsException(e.toString());
    } on bdk.CoinSelectionCreateTxException catch (e) {
      if (hasManualSelection) {
        throw SelectedBitcoinCoinsInsufficientException();
      }
      throw InsufficientFundsException(e.errorMessage);
    }

    if (hasManualSelection) {
      final transaction = psbt.extractTx();
      try {
        final actualInputKeys = {
          for (final input in transaction.input())
            '${input.previousOutput.txid}:${input.previousOutput.vout}',
        };
        if (actualInputKeys.length != selectedKeys.length ||
            !actualInputKeys.containsAll(selectedKeys)) {
          throw SelectedBitcoinCoinsUnavailableException();
        }
      } finally {
        transaction.dispose();
      }
    }

    final inputs = psbt.input();
    final outputs = psbt.output();
    final serialized = _removeFixedBip341NumsKeyOrigins(
      psbt.serialize(),
      inputs: inputs,
      outputs: outputs,
    );
    if (requiredDescriptorKeys == null) return serialized;
    final transaction = psbt.extractTx();
    try {
      final keychainsByOutpoint = {
        for (final utxo in unspents)
          '${utxo.outpoint.txid}:${utxo.outpoint.vout}': utxo.keychain,
      };
      final inputKeychains = [
        for (final input in transaction.input())
          keychainsByOutpoint['${input.previousOutput.txid}:${input.previousOutput.vout}'] ??
              (throw StateError('Built transaction contains an unknown input')),
      ];
      final selectedOrigins = _retainSelectedSegwitKeyOrigins(
        serialized,
        inputKeychains: inputKeychains,
        requiredDescriptorKeys: requiredDescriptorKeys,
      );
      return _retainSelectedTaprootSpendPaths(
        selectedOrigins,
        inputs: inputs,
        inputKeychains: inputKeychains,
        requiredDescriptorKeys: requiredDescriptorKeys,
      );
    } finally {
      transaction.dispose();
    }
  }

  int decodeTxSize(String psbtString, {required PublicBdkWalletModel wallet}) {
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
        final descriptorWallet = BdkFacade.createEphemeralDescriptorWallet(
          descriptor: wallet.descriptor,
          isTestnet: wallet.isTestnet,
        );
        try {
          final keychains = <BitcoinPolicyKeychain>[];
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

  bool validatePolicyPreimage(BitcoinPolicyPreimage preimage) {
    final input = _psbtPreimage(preimage);
    return hex.encode(_preimageHash(input)) == preimage.hash;
  }

  String applyPolicyPreimages(
    String psbtBase64,
    List<BitcoinPolicyPreimage> preimages,
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

  Future<int> getFeeAmount(String psbtString) async {
    final psbt = _parsePsbt(psbtString);
    final fee = psbt.fee();
    return fee;
  }

  Future<int> getAmountSentToAddress(
    String psbtString,
    String address, {
    required bool isTestnet,
  }) async {
    final psbt = _parsePsbt(psbtString);
    final tx = psbt.extractTx();
    final outputs = tx.output();
    int totalAmount = 0;
    for (final output in outputs) {
      final scriptPubkey = output.scriptPubkey;
      final outputAddress = bdk.Address.fromScript(
        script: bdk.Script(rawOutputScript: scriptPubkey.toBytes()),
        network: isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin,
      );
      if (outputAddress.toString() == address) {
        totalAmount += output.value.toSat();
      }
    }
    return totalAmount;
  }
  // 25000 - 988

  Future<({String psbt, bool isFinalized})> signPsbt(
    String unsignedPsbt, {
    required PrivateBdkWalletModel wallet,
    bool allowFinalizedForeignInputs = false,
  }) async {
    final psbt = _parsePsbt(unsignedPsbt);
    try {
      final inputs = psbt.input();
      _validatePartialSignatures(
        unsignedPsbt,
        inputs: inputs,
        allowFinalizedTaprootInputs: allowFinalizedForeignInputs,
      );
      if (!allowFinalizedForeignInputs) {
        _rejectFinalizedInputs(inputs);
      }
      final selectedUnsignedPsbt = _removeFixedBip341NumsKeyOrigins(
        unsignedPsbt,
        inputs: inputs,
        outputs: psbt.output(),
      );
      final signWithTapInternalKey = _shouldSignWithTapInternalKey(inputs);
      final bdkWallet = await BdkFacade.createPrivateWallet(wallet);
      try {
        if (allowFinalizedForeignInputs) {
          _rejectFinalizedWalletInputs(psbt, inputs, bdkWallet);
        }
        bdkWallet.sign(
          psbt: psbt,
          signOptions: bdk.SignOptions(
            trustWitnessUtxo: true,
            assumeHeight: null,
            allowAllSighashes: false,
            tryFinalize: false,
            signWithTapInternalKey: signWithTapInternalKey,
            allowGrinding: true,
          ),
        );
        final signed = inputs.every(_isFinalizedInput)
            ? (psbt: psbt.serialize(), isFinalized: true)
            : _finalizeCompletePsbt(psbt);
        if (!signed.isFinalized) {
          log.info('Signed PSBT is not finalized');
        } else {
          log.info('Signed PSBT is finalized');
        }
        return (
          psbt: signed.isFinalized
              ? signed.psbt
              : _restoreSelectedTaprootMetadata(
                  originalPsbtBase64: selectedUnsignedPsbt,
                  signedPsbtBase64: signed.psbt,
                ),
          isFinalized: signed.isFinalized,
        );
      } finally {
        bdkWallet.dispose();
      }
    } finally {
      psbt.dispose();
    }
  }

  BitcoinWalletPolicyModel analyzePolicy({
    required PublicBdkWalletModel wallet,
    List<WalletDescriptorKeyModel> descriptorKeys = const [],
  }) {
    final parsedDescriptor = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: wallet.descriptor,
      isTestnet: wallet.isTestnet,
    );
    final bdkWallet = BdkFacade.createEphemeralDescriptorWallet(
      descriptor: wallet.descriptor,
      isTestnet: wallet.isTestnet,
    );
    final keyIdentityWallet = descriptorKeys.isEmpty
        ? null
        : BdkFacade.createEphemeralDescriptorWallet(
            descriptor: BdkFacade.descriptorForPolicyAnalysis(
              wallet.descriptor,
            ),
            isTestnet: wallet.isTestnet,
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

      return BitcoinWalletPolicyMapper.fromBdk(
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

  Future<BitcoinPsbtReviewModel> inspectPsbt(
    String psbtBase64, {
    required PublicBdkWalletModel wallet,
    required Set<String> walletFingerprints,
  }) async {
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

        final descriptorWallet = await BdkFacade.createWallet(wallet);
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
              keychain: ownership.keychain == BitcoinPolicyKeychain.external
                  ? BitcoinPolicyKeychainModel.external
                  : BitcoinPolicyKeychainModel.internal,
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
                isTestnet: wallet.isTestnet,
              ),
              amountSat: BigInt.from(txOut.value.toSat()),
              index: index,
              isWalletOwned: ownership != null,
              scriptHex: hex.encode(txOut.scriptPubkey.toBytes()),
            ));
          }

          return BitcoinPsbtReviewModel(
            transactionId: transaction.computeTxid().toString(),
            inputs: inputs,
            outputs: outputs,
            feeSat: BigInt.from(psbt.fee()),
            estimatedTransactionVsize: _completedTransactionVsize(
              transaction: transaction,
              inputs: psbtInputs,
              inputKeychains: inputs
                  .map(
                    (input) =>
                        input.keychain == BitcoinPolicyKeychainModel.external
                        ? BitcoinPolicyKeychain.external
                        : BitcoinPolicyKeychain.internal,
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

  Future<void> validateWalletPsbtInputs(
    String psbtBase64, {
    required PublicBdkWalletModel wallet,
    Set<String> frozenOutpoints = const {},
    String? replacingTxid,
    bool allowSpentWalletInputs = false,
  }) async {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final transaction = psbt.extractTx();
      try {
        final transactionInputs = transaction.input();
        final psbtInputs = psbt.input();
        if (transactionInputs.length != psbtInputs.length) {
          throw const InvalidBitcoinPsbtException();
        }

        final bdkWallet = await BdkFacade.createWallet(wallet);
        try {
          final replacedOutpoints = replacingTxid == null
              ? const <String>{}
              : _transactionInputOutpoints(bdkWallet, replacingTxid);
          final outputs = {
            for (final output in bdkWallet.listOutput())
              '${output.outpoint.txid}:${output.outpoint.vout}': output,
          };
          final seenOutpoints = <String>{};
          for (final (index, transactionInput) in transactionInputs.indexed) {
            final previousOutput = transactionInput.previousOutput;
            final outpoint = '${previousOutput.txid}:${previousOutput.vout}';
            if (!seenOutpoints.add(outpoint)) {
              throw const InvalidBitcoinPsbtException();
            }
            if (frozenOutpoints.contains(outpoint)) {
              throw const BitcoinPsbtFrozenUtxoException();
            }
            final localOutput = outputs[outpoint];
            if (localOutput == null ||
                (localOutput.isSpent &&
                    !allowSpentWalletInputs &&
                    !replacedOutpoints.contains(outpoint))) {
              throw const BitcoinPsbtMissingUtxoException();
            }
            final expected = localOutput.txout;
            final supplied = _inputUtxo(psbtInputs[index], previousOutput);
            if (supplied.value.toSat() != expected.value.toSat() ||
                !_sameBytes(
                  supplied.scriptPubkey.toBytes(),
                  expected.scriptPubkey.toBytes(),
                )) {
              throw const InvalidBitcoinPsbtException();
            }
          }
        } finally {
          bdkWallet.dispose();
        }
      } finally {
        transaction.dispose();
      }
    } finally {
      psbt.dispose();
    }
  }

  Set<String> _transactionInputOutpoints(bdk.Wallet wallet, String txid) {
    final parsedTxid = bdk.Txid.fromString(hex: txid);
    try {
      final transaction = wallet.getTx(txid: parsedTxid)?.transaction;
      if (transaction == null) {
        throw const BitcoinPsbtMissingUtxoException();
      }
      try {
        return {
          for (final input in transaction.input())
            '${input.previousOutput.txid}:${input.previousOutput.vout}',
        };
      } finally {
        transaction.dispose();
      }
    } finally {
      parsedTxid.dispose();
    }
  }

  Future<BitcoinPolicyMaturityModel> getPolicyMaturity({
    required PublicBdkWalletModel wallet,
    ElectrumConnection? electrumServer,
    required bool includeTimeBasedLocks,
    bool includeRelativeTimeLocks = true,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    try {
      final unspents = bdkWallet.listUnspent();
      var tipHeight = bdkWallet.latestCheckpoint().height;
      int? medianTimePast;
      final confirmationMedianTimes = <int, int>{};

      if (electrumServer != null) {
        final referenceHeights =
            includeTimeBasedLocks && includeRelativeTimeLocks
            ? unspents
                  .map((utxo) => utxo.chainPosition)
                  .whereType<bdk.ConfirmedChainPosition>()
                  .map(
                    (position) => max(
                      0,
                      position.confirmationBlockTime.blockId.height - 1,
                    ),
                  )
                  .toSet()
                  .toList()
            : const <int>[];
        final chainState = await compute(
          _fetchPolicyChainState,
          _PolicyChainStateParams(
            electrumUrl: electrumServer.url,
            electrumSocks5: electrumServer.socks5,
            electrumTimeout: electrumServer.effectiveTimeout,
            electrumRetry: electrumServer.retry,
            electrumValidateDomain: electrumServer.validateDomain,
            includeMedianTimePast: includeTimeBasedLocks,
            referenceHeights: referenceHeights,
          ),
        );
        tipHeight = chainState.tipHeight;
        medianTimePast = chainState.medianTimePast;
        confirmationMedianTimes.addAll(chainState.referenceMedianTimes);
      }

      return BitcoinPolicyMaturityModel(
        tipHeight: tipHeight,
        medianTimePast: medianTimePast,
        utxos: [
          for (final utxo in unspents)
            BitcoinPolicyUtxoMaturityModel(
              outpoint: '${utxo.outpoint.txid}:${utxo.outpoint.vout}',
              keychain: utxo.keychain == bdk.KeychainKind.external_
                  ? BitcoinPolicyKeychainModel.external
                  : BitcoinPolicyKeychainModel.internal,
              amountSat: BigInt.from(utxo.txout.value.toSat()),
              confirmations: confirmationsFromTip(
                tip: tipHeight,
                height: utxo.chainPosition is bdk.ConfirmedChainPosition
                    ? (utxo.chainPosition as bdk.ConfirmedChainPosition)
                          .confirmationBlockTime
                          .blockId
                          .height
                    : null,
              ),
              confirmationMedianTimePast:
                  utxo.chainPosition is bdk.ConfirmedChainPosition
                  ? confirmationMedianTimes[max(
                      0,
                      (utxo.chainPosition as bdk.ConfirmedChainPosition)
                              .confirmationBlockTime
                              .blockId
                              .height -
                          1,
                    )]
                  : null,
            ),
        ],
      );
    } finally {
      bdkWallet.dispose();
    }
  }

  /// Partially signs a PSBT with private keys in the supplied descriptors.
  ///
  /// The descriptors and wallet are kept in memory only.
  ({String psbt, bool isFinalized}) signPsbtWithDescriptor(
    String psbtBase64, {
    required String descriptor,
    required bool isTestnet,
    bool tryFinalize = true,
  }) {
    final psbt = _parsePsbt(psbtBase64);
    try {
      final inputs = psbt.input();
      _validatePartialSignatures(psbtBase64, inputs: inputs);
      _rejectFinalizedInputs(inputs);
      final selectedUnsignedPsbt = _removeFixedBip341NumsKeyOrigins(
        psbtBase64,
        inputs: inputs,
        outputs: psbt.output(),
      );
      final signWithTapInternalKey = _shouldSignWithTapInternalKey(inputs);
      final wallet = BdkFacade.createEphemeralDescriptorWallet(
        descriptor: descriptor,
        isTestnet: isTestnet,
      );
      try {
        wallet.sign(
          psbt: psbt,
          signOptions: bdk.SignOptions(
            trustWitnessUtxo: true,
            assumeHeight: null,
            allowAllSighashes: false,
            tryFinalize: false,
            signWithTapInternalKey: signWithTapInternalKey,
            allowGrinding: true,
          ),
        );
        final signed = tryFinalize
            ? _finalizeCompletePsbt(psbt)
            : (psbt: psbt.serialize(), isFinalized: false);
        final normalizedSignedPsbt = _removeFixedBip341NumsKeyOrigins(
          signed.psbt,
          inputs: psbt.input(),
          outputs: psbt.output(),
        );
        return (
          psbt: signed.isFinalized
              ? normalizedSignedPsbt
              : _restoreSelectedTaprootMetadata(
                  originalPsbtBase64: selectedUnsignedPsbt,
                  signedPsbtBase64: normalizedSignedPsbt,
                ),
          isFinalized: signed.isFinalized,
        );
      } finally {
        wallet.dispose();
      }
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

  Future<List<WalletUtxoModel>> getUtxos({required WalletModel wallet}) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final unspent = bdkWallet.listUnspent();
    // Chain tip read once from the already-synced wallet (no extra network
    // calls); reused for every utxo's confirmation count.
    final tip = bdkWallet.latestCheckpoint().height;
    final utxos = await Future.wait(
      unspent.map((unspent) async {
        final address =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              unspent.txout.scriptPubkey.toBytes(),
              isTestnet: wallet.isTestnet,
            );
        // Confirmation count from the utxo's chain position (mirrors the
        // handling in getTransactions); unconfirmed utxos report 0.
        final chainPosition = unspent.chainPosition;
        final confirmedHeight = chainPosition is bdk.ConfirmedChainPosition
            ? chainPosition.confirmationBlockTime.blockId.height
            : null;
        final confirmations = confirmationsFromTip(
          tip: tip,
          height: confirmedHeight,
        );
        return WalletUtxoModel.bitcoin(
          txId: unspent.outpoint.txid.toString(),
          vout: unspent.outpoint.vout,
          amountSat: BigInt.from(unspent.txout.value.toSat()),
          scriptPubkey: unspent.txout.scriptPubkey.toBytes(),
          // Since it's a BDK utxo, the address should not be null
          // but we return an empty string in case it is for some reason
          address: address ?? '',
          isExternalKeyChain: unspent.keychain == bdk.KeychainKind.external_,
          confirmations: confirmations,
        );
      }),
    );
    return utxos;
  }

  Future<List<WalletTransactionModel>> getTransactions({
    required WalletModel wallet,
    String? toAddress,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);

    final transactions = bdkWallet.transactions();

    final allTransactionOutputs = await _getAllOutputsOfTransactions(
      transactions,
      wallet: wallet,
      bdkWallet: bdkWallet,
    );

    // Map the transactions to WalletTransactionModel
    final List<WalletTransactionModel?> walletTxs = await Future.wait(
      transactions.map((tx) async {
        final (inputs, outputs) = (
          tx.transaction.input(),
          tx.transaction.output(),
        );

        if (toAddress != null && toAddress.isNotEmpty) {
          // Filter transactions by address by returning null for non-matching transactions
          // and then removing null values from the list with whereType at the end of the method
          final matches = await Future.any(
            outputs.map((output) async {
              final address =
                  await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                    output.scriptPubkey.toBytes(),
                    isTestnet: wallet.isTestnet,
                  );
              if (address == null) return false;
              return address == toAddress;
            }),
          ).catchError((_) => false);

          if (!matches) return null;
        }

        // Map inputs and outputs to their respective models
        final inputModels = inputs.asMap().entries.map((entry) {
          final input = entry.value;
          final vin = entry.key;
          final previousOutput = input.previousOutput;
          final output = allTransactionOutputs.firstWhereOrNull(
            (output) =>
                output.txId == previousOutput.txid.toString() &&
                output.vout == previousOutput.vout,
          );

          return TransactionInputModel.bitcoin(
            txId: tx.transaction.computeTxid().toString(),
            vin: vin,
            isOwn: output?.isOwn ?? false,
            scriptSig: input.scriptSig.toBytes(),
            previousTxId: previousOutput.txid.toString(),
            previousTxVout: previousOutput.vout,
          );
        }).toList();
        final outputModels = allTransactionOutputs
            .where(
              (output) =>
                  output.txId == tx.transaction.computeTxid().toString(),
            )
            .toList();

        // Check if all inputs and outputs are owned by the wallet itself
        final isToSelf =
            inputModels.every((input) => input.isOwn) &&
            outputModels.every((output) => output.isOwn);

        final sentAndReceived = bdkWallet.sentAndReceived(tx: tx.transaction);
        final received = sentAndReceived.received.toSat();
        final sent = sentAndReceived.sent.toSat();
        final fee = bdkWallet.calculateFee(tx: tx.transaction).toSat();
        final chainPosition = tx.chainPosition;
        int? confirmationTime;
        if (chainPosition is bdk.ConfirmedChainPosition) {
          final blockTime = chainPosition.confirmationBlockTime;

          confirmationTime = blockTime.confirmationTime;
        }

        final isIncoming = received > sent;
        final netAmountSat = _netAmountSatOf(
          isToSelf: isToSelf,
          isIncoming: isIncoming,
          outputs: outputModels,
          sent: sent,
          received: received,
          fee: fee,
        );

        return WalletTransactionModel(
          txId: tx.transaction.computeTxid().toString(),
          isIncoming: isIncoming,
          amountSat: netAmountSat.toInt(),
          feeSat: fee.toInt(),
          vsize: tx.transaction.vsize().toInt(),
          confirmationTimestamp: confirmationTime,
          isToSelf: isToSelf,
          inputs: inputModels,
          outputs: outputModels,
          isLiquid: false,
          isTestnet: wallet.isTestnet,
          isRbf: tx.transaction.isExplicitlyRbf(),
        );
      }),
    );

    return walletTxs.whereType<WalletTransactionModel>().toList();
  }

  Future<({String address, int index})> getNewAddress({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final addressInfo = bdkWallet.revealNextAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
    );

    // Persist the revealed address to avoid address reuse
    await BdkFacade.saveWallet(bdkWallet, wallet.hexId);

    final index = addressInfo.index;
    final address = addressInfo.address.toString();

    return (index: index, address: address);
  }

  Future<({String address, int index})> getLastRevealedAddressOrNew({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final lastRevealedAddressIndex = await getLastRevealedAddressIndex(
      wallet: wallet,
      isChange: isChange,
    );

    if (lastRevealedAddressIndex < 0) {
      // No address has been revealed yet, so we get a new one
      return getNewAddress(wallet: wallet, isChange: isChange);
    }

    final address = await getAddressByIndex(
      lastRevealedAddressIndex,
      wallet: wallet,
    );

    if (await isAddressUsed(address, wallet: wallet)) {
      // If the last revealed address has been used,
      //  we need to get a new one to avoid address reuse
      return getNewAddress(wallet: wallet, isChange: isChange);
    }

    return (index: lastRevealedAddressIndex, address: address);
  }

  // This can return -1 if no address has been revealed yet.
  // This should be handled accordingly by the caller.
  Future<int> getLastRevealedAddressIndex({
    required WalletModel wallet,
    bool isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final nextAddress = bdkWallet.revealNextAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
    );

    final index =
        nextAddress.index -
        1; // Subtract 1 to get the last revealed address index

    return index;
  }

  Future<String> getAddressByIndex(
    int index, {
    required WalletModel wallet,
    isChange = false,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final addressInfo = bdkWallet.peekAddress(
      keychain: isChange
          ? bdk.KeychainKind.internal
          : bdk.KeychainKind.external_,
      index: index,
    );

    final address = addressInfo.address.toString();

    return address;
  }

  Future<bool> isAddressUsed(
    String address, {
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final transactions = bdkWallet.transactions();

    // TODO: Use future.wait to parallelize the loop and improve performance
    for (final tx in transactions) {
      final txOutputs = tx.transaction.output();

      for (final output in txOutputs) {
        final generatedAddress =
            await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
              output.scriptPubkey.toBytes(),
              isTestnet: wallet.isTestnet,
            );
        if (generatedAddress == null) continue;
        if (generatedAddress == address) {
          return true;
        }
      }
    }

    return false;
  }

  Future<Map<String, BigInt>> getAddressBalancesSat({
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    final utxos = bdkWallet.listUnspent();
    final addressBalances = <String, BigInt>{};

    for (final utxo in utxos) {
      final utxoAddress =
          await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
            utxo.txout.scriptPubkey.toBytes(),
            isTestnet: wallet.isTestnet,
          );
      if (utxoAddress == null) continue;

      addressBalances[utxoAddress] =
          (addressBalances[utxoAddress] ?? BigInt.zero) +
          BigInt.from(utxo.txout.value.toSat());
    }

    return addressBalances;
  }

  /// The amount to show for a transaction, from this wallet's point of view.
  static int _netAmountSatOf({
    required bool isToSelf,
    required bool isIncoming,
    required List<BitcoinTransactionOutputModel> outputs,
    required int sent,
    required int received,
    required int fee,
  }) {
    if (isToSelf) {
      // `sent` is the whole utxo we spent, not what we paid: coin selection
      // spends whole utxos and hands the rest back as change.
      final toDestination = outputs
          .where((output) => !output.isChange)
          .fold(0, (sum, output) => sum + (output.value?.toInt() ?? 0));
      // Nothing paid out — a consolidation. The fee is the only balance change.
      return toDestination > 0 ? toDestination : fee;
    }

    // The sender paid the fee, so it never left this balance.
    if (isIncoming) return received - sent;

    // We paid the fee, so take it off to leave what reached the recipient.
    return sent - received - fee;
  }

  Future<List<BitcoinTransactionOutputModel>> _getAllOutputsOfTransactions(
    List<bdk.CanonicalTx> transactions, {
    required WalletModel wallet,
    required bdk.Wallet bdkWallet,
  }) async {
    // Our own change outputs, by outpoint. In a send-to-self every output is
    // ours, so only the keychain separates the recipient from the change.
    // `listOutput()` covers spent outputs too, and hits no network.
    final changeOutpoints = <Outpoint>{
      for (final output in bdkWallet.listOutput())
        if (output.keychain == bdk.KeychainKind.internal)
          (txId: output.outpoint.txid.toString(), vout: output.outpoint.vout),
    };

    final listOfOutputs = await Future.wait(
      transactions.map((tx) async {
        final outputs = tx.transaction.output();
        final models = await Future.wait(
          outputs.asMap().entries.map((outputEntry) async {
            final vout = outputEntry.key;
            final output = outputEntry.value;
            final txId = tx.transaction.computeTxid().toString();
            final scriptPubkeyBytes = output.scriptPubkey.toBytes();
            final address =
                await AddressScriptConversions.bitcoinAddressFromScriptPubkey(
                  output.scriptPubkey.toBytes(),
                  isTestnet: wallet.isTestnet,
                );

            return TransactionOutputModel.bitcoin(
              txId: txId,
              vout: vout,
              isOwn: await isMine(
                scriptPubkeyBytes,
                wallet: wallet,
                bdkWallet: bdkWallet,
              ),
              value: BigInt.from(output.value.toSat()),
              scriptPubkey: scriptPubkeyBytes,
              address: address,
              isChange: changeOutpoints.contains((txId: txId, vout: vout)),
            );
          }),
        );
        return models;
      }),
    );

    final allOutputs = listOfOutputs.expand((i) => i).toList();
    return allOutputs.whereType<BitcoinTransactionOutputModel>().toList();
  }

  Future<String> createUnsignedReplaceByFeePsbt({
    required String txid,
    required RelativeFee feeRate,
    required WalletModel wallet,
  }) async {
    final bdkWallet = await BdkFacade.createWallet(wallet);
    // BumpFeeTxBuilder is rate-only by BDK design (BIP-125 requires a
    // higher rate, not absolute, to replace). We hit it with sat/kwu so
    // sub-1 sat/vByte bumps survive without precision loss.
    final tx = bdk.BumpFeeTxBuilder(
      txid: bdk.Txid.fromString(hex: txid),
      feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: feeRate.satPerKwu),
    );
    final psbt = tx.finish(wallet: bdkWallet);
    return psbt.serialize();
  }

  Future<void> delete({required WalletModel wallet}) async {
    await BdkFacade.delete(wallet);
    log.fine('Deleted wallet ${wallet.id} BDK database');
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required List<int> entropy,
    required String passphrase,
    required ScriptType scriptType,
    required bool isTestnet,
    required ElectrumConnection electrumServer,
  }) {
    return compute(
      _performDryScan,
      _DryScanParams(
        entropy: entropy,
        passphrase: passphrase,
        scriptType: scriptType,
        isTestnet: isTestnet,
        electrumUrl: electrumServer.url,
        electrumSocks5: electrumServer.socks5,
        electrumStopGap: electrumServer.stopGap,
        electrumTimeout: electrumServer.effectiveTimeout,
        electrumRetry: electrumServer.retry,
        electrumValidateDomain: electrumServer.validateDomain,
        rootIsolateToken: ServicesBinding.rootIsolateToken!,
      ),
    );
  }
}

// Top-level function for isolate execution
class _SyncParams {
  final String walletId;
  final String descriptor;
  final bool isTestnet;
  final String electrumUrl;
  final String? electrumSocks5;
  final int electrumStopGap;
  final int electrumTimeout;
  final int electrumRetry;
  final bool electrumValidateDomain;
  final String walletHexId;
  final RootIsolateToken rootIsolateToken;

  _SyncParams({
    required this.walletId,
    required this.descriptor,
    required this.isTestnet,
    required this.electrumUrl,
    required this.electrumSocks5,
    required this.electrumStopGap,
    required this.electrumTimeout,
    required this.electrumRetry,
    required this.electrumValidateDomain,
    required this.walletHexId,
    required this.rootIsolateToken,
  });
}

Future<void> _performFullScan(_SyncParams params) async {
  // Initialize the binary messenger for platform channel access in isolate
  // Needed for things like getting the database path from BdkFacade which
  // uses path_provider under the hood
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  // Recreate wallet model in the isolate
  final wallet = WalletModel.publicBdk(
    id: params.walletId,
    descriptor: params.descriptor,
    isTestnet: params.isTestnet,
  );

  final bdkWallet = await BdkFacade.createWallet(wallet);
  final blockchain = _createElectrumClient(
    url: params.electrumUrl,
    socks5: params.electrumSocks5,
    timeout: params.electrumTimeout,
    retry: params.electrumRetry,
    validateDomain: params.electrumValidateDomain,
  );
  try {
    final scanRequest = bdkWallet.startFullScan().build();
    final update = blockchain.fullScan(
      request: scanRequest,
      stopGap: params.electrumStopGap,
      batchSize: _batchSizeFor(params.electrumStopGap),
      fetchPrevTxouts: true,
    );
    bdkWallet.applyUpdate(update: update);
  } catch (e, st) {
    log.warning(
      'full_scan failed for wallet ${params.walletId}',
      error: e,
      trace: st,
    );
    rethrow;
  }
  await BdkFacade.saveWallet(bdkWallet, params.walletHexId);
}

class FailedToSignPsbtException extends BullException {
  FailedToSignPsbtException(super.message);
}

class UnsupportedBdkNetworkException extends BullException {
  UnsupportedBdkNetworkException(super.message);
}

/// Confirmation count for an output confirmed at [height], given the current
/// chain [tip]. A `null` height (unconfirmed) returns 0; the result is clamped
/// to 0 to guard a reorg / mid-sync window where `tip < height` (D2).
int confirmationsFromTip({required int tip, required int? height}) {
  if (height == null) return 0;
  return max(0, tip - height + 1);
}

final class _PolicyChainStateParams {
  final String electrumUrl;
  final String? electrumSocks5;
  final int electrumTimeout;
  final int electrumRetry;
  final bool electrumValidateDomain;
  final bool includeMedianTimePast;
  final List<int> referenceHeights;

  const _PolicyChainStateParams({
    required this.electrumUrl,
    required this.electrumSocks5,
    required this.electrumTimeout,
    required this.electrumRetry,
    required this.electrumValidateDomain,
    required this.includeMedianTimePast,
    required this.referenceHeights,
  });
}

final class _PolicyChainState {
  final int tipHeight;
  final int? medianTimePast;
  final Map<int, int> referenceMedianTimes;

  const _PolicyChainState({
    required this.tipHeight,
    required this.medianTimePast,
    required this.referenceMedianTimes,
  });
}

_PolicyChainState _fetchPolicyChainState(_PolicyChainStateParams params) {
  final client = _createElectrumClient(
    url: params.electrumUrl,
    socks5: params.electrumSocks5,
    timeout: params.electrumTimeout,
    retry: params.electrumRetry,
    validateDomain: params.electrumValidateDomain,
  );
  try {
    final tip = client.blockHeadersSubscribe();
    final referenceMedianTimes = <int, int>{};
    for (final requestedHeight in params.referenceHeights) {
      final height = min(requestedHeight, tip.height);
      referenceMedianTimes[requestedHeight] = electrumMedianTimePast(
        client: client,
        height: height,
      );
    }
    return _PolicyChainState(
      tipHeight: tip.height,
      medianTimePast: params.includeMedianTimePast
          ? electrumMedianTimePast(
              client: client,
              height: tip.height,
              knownHeader: tip.header,
            )
          : null,
      referenceMedianTimes: referenceMedianTimes,
    );
  } finally {
    client.dispose();
  }
}

class _DryScanParams {
  final List<int> entropy;
  final String passphrase;
  final ScriptType scriptType;
  final bool isTestnet;
  final String electrumUrl;
  final String? electrumSocks5;
  final int electrumStopGap;
  final int electrumTimeout;
  final int electrumRetry;
  final bool electrumValidateDomain;
  final RootIsolateToken rootIsolateToken;

  _DryScanParams({
    required this.entropy,
    required this.passphrase,
    required this.scriptType,
    required this.isTestnet,
    required this.electrumUrl,
    required this.electrumSocks5,
    required this.electrumStopGap,
    required this.electrumTimeout,
    required this.electrumRetry,
    required this.electrumValidateDomain,
    required this.rootIsolateToken,
  });
}

Future<({BigInt satoshis, int transactions})> _performDryScan(
  _DryScanParams params,
) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(params.rootIsolateToken);

  final bdkNetwork = params.isTestnet
      ? bdk.Network.testnet
      : bdk.Network.bitcoin;
  final bdkNetworkKind = params.isTestnet
      ? bdk.NetworkKind.test
      : bdk.NetworkKind.main;

  final bdkMnemonic = bdk.Mnemonic.fromEntropy(
    entropy: Uint8List.fromList(params.entropy),
  );

  final descriptorSecretKey = bdk.DescriptorSecretKey(
    networkKind: bdkNetworkKind,
    mnemonic: bdkMnemonic,
    password: params.passphrase,
  );

  final (external, internal) = switch (params.scriptType) {
    ScriptType.bip84 => (
      bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: bdkNetworkKind,
      ),
      bdk.Descriptor.newBip84(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: bdkNetworkKind,
      ),
    ),
    ScriptType.bip49 => (
      bdk.Descriptor.newBip49(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: bdkNetworkKind,
      ),
      bdk.Descriptor.newBip49(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: bdkNetworkKind,
      ),
    ),
    ScriptType.bip44 => (
      bdk.Descriptor.newBip44(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.external_,
        networkKind: bdkNetworkKind,
      ),
      bdk.Descriptor.newBip44(
        secretKey: descriptorSecretKey,
        keychainKind: bdk.KeychainKind.internal,
        networkKind: bdkNetworkKind,
      ),
    ),
  };

  final wallet = bdk.Wallet(
    descriptor: external,
    changeDescriptor: internal,
    network: bdkNetwork,
    persister: bdk.Persister.newInMemory(),
    lookahead: 0,
  );

  final blockchain = _createElectrumClient(
    url: params.electrumUrl,
    socks5: params.electrumSocks5,
    timeout: params.electrumTimeout,
    retry: params.electrumRetry,
    validateDomain: params.electrumValidateDomain,
  );

  try {
    final scanRequest = wallet.startFullScan().build();
    final update = blockchain.fullScan(
      request: scanRequest,
      stopGap: params.electrumStopGap,
      batchSize: _batchSizeFor(params.electrumStopGap),
      fetchPrevTxouts: false,
    );
    wallet.applyUpdate(update: update);
  } catch (e, st) {
    log.warning('probe_scan failed', error: e, trace: st);
    rethrow;
  }

  final balance = wallet.balance();
  final transactions = wallet.transactions();

  return (
    satoshis: BigInt.from(balance.confirmed.toSat()),
    transactions: transactions.length,
  );
}

int _batchSizeFor(int stopGap) => (stopGap ~/ 4).clamp(50, 1000);

/// Creates a [bdk.ElectrumClient], retrying once on the rustls CryptoProvider
/// install race across concurrent isolates (full scan, dry scan, sync).
/// electrum-client's install_default check+install is not atomic, so two
/// isolates can both see "not installed" and the loser fails. On retry the
/// provider is already installed and the check short-circuits.
bdk.ElectrumClient _createElectrumClient({
  required String url,
  required String? socks5,
  required int timeout,
  required int retry,
  required bool validateDomain,
}) {
  bdk.ElectrumClient build() => bdk.ElectrumClient(
    url: url,
    socks5: socks5?.isNotEmpty == true ? socks5 : null,
    timeout: timeout.clamp(0, 255),
    retry: retry.clamp(0, 255),
    validateDomain: validateDomain,
  );
  try {
    return build();
  } on bdk.CouldNotCreateConnectionElectrumException catch (e) {
    if (e.errorMessage.contains('Failed to install CryptoProvider')) {
      return build();
    }
    rethrow;
  }
}
