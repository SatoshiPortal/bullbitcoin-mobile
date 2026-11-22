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

import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

import 'package:fees/fees.dart';
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:primitives/primitives.dart'
    show Err, Ok, Result, Sats, BitcoinTransactionRecipient;
import 'package:secrets/secrets.dart';
import 'package:electrum/setup.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';

class BitcoinWalletRepository implements BitcoinSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final ArkFundingSigningGuard _arkFundingGuard;
  final Future<Result<sync.Wallet, SyncFailure>> Function(WalletKey) _wallet;
  final SyncWalletValuesDatasource _values;

  BitcoinWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required this._arkFundingGuard,
    required this._wallet,
    required SyncWalletValuesDatasource walletValuesDatasource,
  }) : _values = walletValuesDatasource;

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

      final sync.BitcoinSpendRequest request;
      try {
        request = sync.BitcoinSpendRequest(
          recipients: [
            for (final recipient in recipients)
              sync.SpendRecipient(
                recipient.address,
                amountSat: recipient.amountSat?.value.toInt(),
              ),
          ],
          fee: switch (networkFee) {
            AbsoluteFee(:final sats) => sync.SpendAbsoluteFee(sats),
            RelativeFee(:final satPerKwu) => sync.SpendFeeRate(satPerKwu),
          },
          selected: selected == null
              ? null
              : [
                  for (final coin in selected)
                    (txId: coin.txId, vout: coin.vout),
                ],
          selectedOnly: selectedOnly,
          replaceable: replaceByFee ?? true,
          exclude: {...?unspendable},
        );
      } on ArgumentError {
        return const Err(WalletTransactionBuildFailure('spend_refused'));
      }
      final key = WalletKey(id: metadata.id, network: metadata.network.shared);
      final built = switch (await _wallet(key)) {
        Ok(:final value) => await value.tx.build(request),
        Err(:final failure) => Err<UnsignedSpend, SyncFailure>(failure),
      };
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
    final metadata = await _metadataFor(walletId);
    return _values.isMine(
      script,
      key: WalletKey(id: metadata.id, network: metadata.network.shared),
    );
  }

  @override
  Future<bool> areAddressesOfWallet(
    List<String> addresses, {
    required String walletId,
  }) async {
    final metadata = await _metadataFor(walletId);
    return _values.areAddressesMine(
      addresses,
      key: WalletKey(id: metadata.id, network: metadata.network.shared),
    );
  }

  @override
  Future<int> getTxSize({required String psbt}) async {
    return sync.decodeBitcoinPsbt(psbt).vsize;
  }

  Future<int> getTxFeeAmount({required String psbt}) async {
    return switch (sync.bitcoinPsbtFee(psbt)) {
      Ok(:final value) => value,
      Err() => throw const FormatException('PSBT fee unknown'),
    };
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
    final amounts = switch (await sync.bitcoinRecipientAmounts(
      psbt: psbt,
      network: metadata.network.bitcoin,
      recipients: [
        for (final recipient in recipients)
          (
            address: recipient.address,
            amountSat: recipient.amountSat?.value.toInt(),
          ),
      ],
    )) {
      Ok(:final value) => value,
      Err(failure: sync.SyncInvalidTransactionFailure()) =>
        throw const FormatException('Not a PSBT'),
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
    return amounts.map(Sats.fromInt).toList();
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
    return switch (await sync.bitcoinRecipientAmounts(
      psbt: psbt,
      network: metadata.network.bitcoin,
      recipients: [(address: address, amountSat: null)],
    )) {
      Ok(:final value) => value.single,
      Err(failure: sync.SyncInvalidTransactionFailure()) =>
        throw const FormatException('Not a PSBT'),
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
  }

  Future<({BigInt satoshis, int transactions})> dryScan({
    required String externalDescriptor,
    required String internalDescriptor,
    required Network network,
    required ElectrumConnection electrumServer,
  }) async {
    final scanned = await sync.prescanBitcoinWallet(
      externalDescriptor: externalDescriptor,
      internalDescriptor: internalDescriptor,
      network: network.bitcoin,
      connection: sync.WalletConnection(
        url: electrumServer.url,
        socks5: electrumServer.socks5,
        timeout: Duration(seconds: electrumServer.effectiveTimeout),
        retry: electrumServer.retry,
        stopGap: electrumServer.stopGap,
        validateDomain: electrumServer.validateDomain,
      ),
    );
    return switch (scanned) {
      Ok(:final value) => (
        satoshis: value.confirmedSat,
        transactions: value.transactions,
      ),
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
  }

  /// Verifies the stored transaction's wallet-owned input signatures against
  /// its watch-only descriptors (GHSA-6jp4-8v48-cc5v guard); no key material
  /// is loaded.
  Future<sync.SignatureCheck> getTransactionSignatureStatus({
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
    final key = WalletKey(id: metadata.id, network: metadata.network.shared);
    final handle = switch (await _wallet(key)) {
      Ok(:final value) => value,
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
    return switch (await handle.tx.originalSignatures(txid)) {
      Ok(:final value) => value,
      Err(:final failure) => throw sync.WalletSnapshotException(failure),
    };
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
    final key = WalletKey(id: metadata.id, network: metadata.network.shared);
    return switch (await _wallet(key)) {
      Ok(:final value) => value.tx.bump(
        sync.BumpFeeRequest(
          txid: txid,
          fee: sync.SpendFeeRate(newFeeRate.satPerKwu),
        ),
      ),
      Err(:final failure) => Err(failure),
    };
  }
}
