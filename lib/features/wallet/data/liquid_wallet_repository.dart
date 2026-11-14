import 'package:sync/read.dart' as sync_read show validateAddress;
import 'package:sync/sync.dart' show TransactionSyncFailure;
import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/wallet/data/lwk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/wallet/domain/liquid_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/consolidation_required_exception.dart';

class LiquidWalletRepository implements LiquidSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final LwkWalletDatasource _lwkWallet;
  final FrozenWalletUtxoDatasource _frozenWalletUtxoDatasource;

  final Future<Result<void, TransactionSyncFailure>> Function(
    String address,
    Network network,
  )
  _validateAddress;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required LwkWalletDatasource lwkWalletDatasource,
    required this._frozenWalletUtxoDatasource,
    Future<Result<void, TransactionSyncFailure>> Function(
      String address,
      Network network,
    )?
    validateAddress,
  }) : _lwkWallet = lwkWalletDatasource,
       _validateAddress = validateAddress ?? sync_read.validateAddress;

  @override
  @useResult
  Future<Result<String, WalletFailure>> buildPset({
    required String walletId,
    required String address,
    int? amountSat,
    required RelativeFee feeRate,
    bool? drain,
    Set<Outpoint>? selectedInputs,
  }) async {
    if (amountSat == null && drain != true) {
      return const Err(WalletTransactionBuildFailure('Amount required'));
    }
    try {
      final metadata = await _walletMetadataDatasource.fetch(walletId);
      if (metadata == null) return const Err(WalletNotFoundFailure());
      if (!metadata.isLiquid) {
        return const Err(WalletTransactionBuildFailure('Not a Liquid wallet'));
      }
      if (await _validateAddress(address, metadata.network.shared) case Err()) {
        return const Err(WalletAddressNetworkMismatchFailure());
      }
      final wallet = WalletModel.publicLwk(
        combinedCtDescriptor: metadata.externalPublicDescriptor,
        network: metadata.network,
        id: metadata.id,
      );
      final frozen = await _frozenOutpoints();
      Set<Outpoint>? inputs = selectedInputs;
      if (selectedInputs != null || frozen.isNotEmpty) {
        final available = {
          for (final utxo in await _lwkWallet.getUtxos(wallet: wallet))
            if (!frozen.contains((txId: utxo.txId, vout: utxo.vout)))
              (txId: utxo.txId, vout: utxo.vout),
        };
        if (selectedInputs != null &&
            (selectedInputs.isEmpty ||
                !available.containsAll(selectedInputs))) {
          return const Err(WalletSelectedInputsUnavailableFailure());
        }
        inputs ??= available;
        if (inputs.isEmpty) return const Err(WalletNoSpendableInputsFailure());
      }
      return Ok(
        await _lwkWallet.buildPset(
          wallet: wallet,
          address: address,
          amountSat: amountSat,
          feeRate: feeRate,
          drain: drain ?? false,
          selectedInputs: inputs,
        ),
      );
    } on InsufficientFundsException {
      return const Err(WalletInsufficientFundsFailure());
    } on ConsolidationRequiredException {
      return const Err(WalletConsolidationRequiredFailure());
    } on NoSpendableUtxoException {
      return const Err(WalletNoSpendableInputsFailure());
    } on Exception {
      return const Err(WalletTransactionBuildFailure());
    }
  }

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    final (size, fees) = await _lwkWallet.decodeAbsoluteFeesFromPset(pset);
    return (size, fees);
  }

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      network: metadata.network,
      id: metadata.id,
    );
    return _lwkWallet.getLbtcUtxoCount(wallet: wallet);
  }

  Future<List<String>> consolidate({
    required String walletId,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      network: metadata.network,
      id: metadata.id,
    );
    return _lwkWallet.consolidate(
      wallet: wallet,
      feeRate: feeRate,
      highUtxoThreshold: highUtxoThreshold,
      maximumInputs: maximumInputs,
      unspendable: await _frozenOutpoints(),
    );
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final frozen = await _frozenOutpoints();
    if (frozen.isNotEmpty &&
        _lwkWallet.getPsetInputs(pset).any(frozen.contains)) {
      throw NoSpendableUtxoException(
        'The transaction spends a frozen Liquid coin',
      );
    }
    final metadata = await _walletMetadataDatasource.fetch(walletId);

    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }

    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }

    // The mnemonic stays inside `secrets`: it builds the lwk wallet in a
    // scratch directory it removes afterwards, signs, and returns only
    // the signed PSET.
    final fingerprint = metadata.seedFingerprint;
    if (fingerprint == null) {
      throw Exception('No secret for wallet: not a seed-derived wallet');
    }
    final secret = switch (await _secrets.fetch(fingerprint)) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('No secret for wallet: $failure'),
    };

    return switch (await secret.sign.pset(
      pset,
      network: metadata.network.liquid,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw Exception('Failed to sign PSET: $failure'),
    };
  }

  Future<Set<Outpoint>> _frozenOutpoints() async => {
    for (final utxo in await _frozenWalletUtxoDatasource.getAllFrozen())
      (txId: utxo.txId, vout: utxo.vout),
  };

  Future<int> getAmountSentToAddress({
    required String pset,
    required String address,
    required String walletId,
  }) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    final wallet = WalletModel.publicLwk(
      combinedCtDescriptor: metadata.externalPublicDescriptor,
      network: metadata.network,
      id: metadata.id,
    );
    return await _lwkWallet.getAmountSentToAddress(
      pset,
      address,
      wallet: wallet,
    );
  }
}
