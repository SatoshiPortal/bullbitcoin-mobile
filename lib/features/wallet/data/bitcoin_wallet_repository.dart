import 'ark_funding_signing_guard.dart';

import 'package:sync/sync.dart' show WalletKey;
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:sync/sync.dart'
    show
        BitcoinSpendStatus,
        SyncBusyFailure,
        SyncFailure,
        SyncInsufficientFundsFailure,
        SyncInvalidAddressFailure,
        SyncNoSpendableInputsFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure,
        UnsignedSpend;

import '../domain/wallet_spend_failure.dart';

import 'package:sync/sync.dart' show validateAddress;
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';

import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_utxo_mapper.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, Result, Sats, BitcoinTransactionRecipient;
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/transaction_signature_status.dart';

class BitcoinWalletRepository implements BitcoinSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final ArkFundingSigningGuard _arkFundingGuard;
  final BdkWalletDatasource _bdkWallet;
  final SyncWalletValuesDatasource _values;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required this._arkFundingGuard,
    required BdkWalletDatasource bdkWalletDatasource,
    required SyncWalletValuesDatasource walletValuesDatasource,
  }) : _bdkWallet = bdkWalletDatasource,
       _values = walletValuesDatasource;

  /// Sync's writer admits the spend, then builds once on a wallet opened for
  /// the build, excluding the freezes and other sessions' reservations it
  /// reads itself, and refusing a selected protected coin: [unspendable]
  /// only narrows what it may use.
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

      for (final recipient in recipients) {
        if (await validateAddress(recipient.address, metadata.network.shared)
            case Err()) {
          return const Err(WalletAddressNetworkMismatchFailure());
        }
      }
      if (selectedOnly && (selected == null || selected.isEmpty)) {
        return const Err(WalletSelectedInputsUnavailableFailure());
      }

      final built = await _bdkWallet.buildPsbt(
        wallet: WalletModel.fromMetadata(metadata),
        recipients: recipients.map(_recipientModelFromEntity).toList(),
        networkFee: networkFee,
        unspendable: unspendable,
        selected: selected
            ?.map((utxo) => WalletUtxoMapper.fromEntity(utxo))
            .toList(),
        selectedOnly: selectedOnly,
        // Default to RBF-enabled, matching BDK's own default sequence
        // (0xFFFFFFFD).
        replaceByFee: replaceByFee ?? true,
      );
      return switch (built) {
        Ok(:final value) => Ok(value.encoded),
        Err(:final failure) => Err(
          _buildFailure(failure, selected: selected != null),
        ),
      };
    } on WalletSpendBlockedException {
      // The spend gate is not a build failure: the caller names it.
      rethrow;
    } on Exception catch (error, trace) {
      log.warning(
        'Bitcoin transaction construction failed',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(WalletTransactionBuildFailure());
    }
  }

  /// The guard's refusals stay exceptions for the callers that name them.
  static WalletFailure _buildFailure(
    SyncFailure failure, {
    required bool selected,
  }) => switch (failure) {
    SyncSpendBlockedFailure(:final status) => throw WalletSpendBlockedException(
      status,
    ),
    SyncBusyFailure() => throw const WalletSpendBlockedException(
      BitcoinSpendStatus.busy,
    ),
    SyncInsufficientFundsFailure() => const WalletInsufficientFundsFailure(),
    SyncNoSpendableInputsFailure() || SyncProtectedInputsFailure() =>
      selected
          ? const WalletSelectedInputsUnavailableFailure()
          : const WalletNoSpendableInputsFailure(),
    SyncInvalidAddressFailure() => const WalletAddressNetworkMismatchFailure(),
    _ => WalletTransactionBuildFailure(failure.logCode),
  };

  /// Signs with the wallet's own key, which never leaves `secrets`.
  ///
  /// The package builds the bdk wallet, signs, and throws it away; this
  /// repository holds no private wallet model, so the mnemonic has no
  /// reason to exist here.
  Future<String> signPsbt(String psbt, {required String walletId}) async {
    final metadata = await _metadataFor(walletId);
    final admission = await _arkFundingGuard.admit(
      key: WalletKey(id: metadata.id, network: metadata.network.shared),
      unsignedPsbt: psbt,
    );
    if (admission case Err()) {
      throw const WalletSpendBlockedException(BitcoinSpendStatus.unavailable);
    }
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

    final wallet = WalletModel.publicBdk(
      externalDescriptor: metadata.externalPublicDescriptor,
      internalDescriptor: metadata.internalPublicDescriptor,
      network: metadata.network,
      id: metadata.id,
    ) as PublicBdkWalletModel;

    final isFromWallet = await _values.isMine(script, wallet: wallet);

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

    final wallet = WalletModel.publicBdk(
      externalDescriptor: metadata.externalPublicDescriptor,
      internalDescriptor: metadata.internalPublicDescriptor,
      network: metadata.network,
      id: metadata.id,
    ) as PublicBdkWalletModel;

    final isFromWallet = await _values.areAddressesMine(
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
      network: metadata.network,
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
      network: metadata.network,
    );
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
    required ElectrumConnection electrumServer,
  }) {
    return _bdkWallet.dryScan(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network,
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

  /// A replacement of [txid] built by sync's writer, only on an original
  /// whose own inputs' signatures verify: the caller signs it, then
  /// broadcasts it with the generation it carries.
  Future<Result<UnsignedSpend, SyncFailure>> bumpFee({
    required String walletId,
    required String txid,
    required RelativeFee newFeeRate,
  }) async {
    final metadata = await _metadataFor(walletId);
    return _bdkWallet.createUnsignedReplaceByFeePsbt(
      wallet: WalletModel.fromMetadata(metadata),
      txid: txid,
      feeRate: newFeeRate,
    );
  }
}
