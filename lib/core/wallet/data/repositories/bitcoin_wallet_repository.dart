import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, Result, Sats, BitcoinTransactionRecipient;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/manipulated_transaction_exception.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';
import 'package:bb_mobile/core/wallet/domain/unverifiable_transaction_exception.dart';

class BitcoinWalletRepository implements BitcoinSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final BdkWalletDatasource _bdkWallet;
  final FrozenWalletUtxoDatasource _frozenUtxos;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required BdkWalletDatasource bdkWalletDatasource,
    required FrozenWalletUtxoDatasource frozenWalletUtxoDatasource,
  }) : _bdkWallet = bdkWalletDatasource,
       _frozenUtxos = frozenWalletUtxoDatasource;

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
                externalDescriptor: metadata.externalPublicDescriptor,
                internalDescriptor: metadata.internalPublicDescriptor,
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
      );

      return Ok(psbt);
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

  /// Signs with the wallet's own key, which never leaves `secrets`.
  ///
  /// The package builds the bdk wallet, signs, and throws it away; this
  /// repository holds no private wallet model, so the mnemonic has no
  /// reason to exist here.
  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final metadata = await _metadataFor(walletId);
    final secret = await _secretFor(metadata);

    return switch (await secret.sign.psbt(
      psbt,
      network: metadata.network.bitcoin,
      scriptType: metadata.scriptType.shared,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('Failed to sign PSBT: $failure'),
    };
  }

  Future<WalletMetadataModel> _metadataFor(String walletId) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }
    return metadata;
  }

  Future<Secret> _secretFor(WalletMetadataModel metadata) async {
    final fingerprint = metadata.seedFingerprint;
    if (fingerprint == null) {
      throw Exception('No secret for wallet: not a seed-derived wallet');
    }
    return switch (await _secrets.fetch(fingerprint)) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('No secret for wallet: $failure'),
    };
  }

  Future<bool> isScriptOfWallet({
    required String walletId,
    required Uint8List script,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    final isFromWallet = await _bdkWallet.isMine(script, wallet: wallet);

    return isFromWallet;
  }

  @override
  Future<bool> areAddressesOfWallet(
    List<String> addresses, {
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isBitcoin) {
      throw Exception('Wallet $walletId is not a Bitcoin wallet');
    }

    final wallet =
        WalletModel.publicBdk(
              externalDescriptor: metadata.externalPublicDescriptor,
              internalDescriptor: metadata.internalPublicDescriptor,
              isTestnet: metadata.isTestnet,
              id: metadata.id,
            )
            as PublicBdkWalletModel;

    final isFromWallet = await _bdkWallet.areAddressesMine(
      addresses,
      wallet: wallet,
    );

    return isFromWallet;
  }

  @override
  Future<int> getTxSize({required String psbt}) async {
    final txSize = await _bdkWallet.decodeTxSize(psbt);
    return txSize;
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
    return signPsbt(psbt, walletId: walletId);
  }
}
