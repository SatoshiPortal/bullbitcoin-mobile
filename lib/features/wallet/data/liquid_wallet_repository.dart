import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:sync/sync.dart' as sync_read show validateAddress;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart'
    show
        SyncConsolidationRequiredFailure,
        SyncFailure,
        SyncInsufficientFundsFailure,
        SyncInvalidAddressFailure,
        SyncNoSpendableInputsFailure,
        SyncProtectedInputsFailure;
import 'package:fees/fees.dart';
import 'package:sync/sync.dart' as sync;
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/wallet/data/sync_freezes_datasource.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/wallet/domain/liquid_send_port.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';

class LiquidWalletRepository implements LiquidSendPort {
  final WalletMetadataDatasource _walletMetadataDatasource;
  final Secrets _secrets;
  final Future<Result<sync.Wallet, SyncFailure>> Function(sync.WalletKey)
  _wallet;
  final SyncWalletValuesDatasource _values;
  final SyncFreezesDatasource _freezes;

  final Future<Result<void, SyncFailure>> Function(
    String address,
    Network network,
  )
  _validateAddress;

  LiquidWalletRepository({
    required this._walletMetadataDatasource,
    required this._secrets,
    required this._wallet,
    required SyncWalletValuesDatasource walletValuesDatasource,
    required SyncFreezesDatasource freezesDatasource,
    Future<Result<void, SyncFailure>> Function(String address, Network network)?
    validateAddress,
  }) : _values = walletValuesDatasource,
       _freezes = freezesDatasource,
       _validateAddress = validateAddress ?? sync_read.validateAddress;

  /// Sync's writer builds once, excluding the freezes it reads itself and
  /// refusing a selected frozen coin.
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
      if (selectedInputs != null && selectedInputs.isEmpty) {
        return const Err(WalletSelectedInputsUnavailableFailure());
      }
      final sync.LiquidSpendRequest request;
      try {
        request = sync.LiquidSpendRequest(
          address: address,
          amountSat: drain == true ? null : amountSat,
          fee: sync.SpendFeeRate(feeRate.satPerKwu),
          selected: selectedInputs,
        );
      } on ArgumentError {
        return const Err(WalletTransactionBuildFailure('spend_refused'));
      }
      final key = sync.WalletKey(
        id: metadata.id,
        network: metadata.network.shared,
      );
      final built = switch (await _wallet(key)) {
        Ok(:final value) => await value.tx.build(request),
        Err(:final failure) => Err<sync.UnsignedSpend, SyncFailure>(failure),
      };
      return switch (built) {
        Ok(:final value) => Ok(value.encoded),
        Err(:final failure) => Err(switch (failure) {
          SyncInsufficientFundsFailure() =>
            const WalletInsufficientFundsFailure(),
          SyncConsolidationRequiredFailure() =>
            const WalletConsolidationRequiredFailure(),
          SyncNoSpendableInputsFailure() || SyncProtectedInputsFailure() =>
            selectedInputs != null
                ? const WalletSelectedInputsUnavailableFailure()
                : const WalletNoSpendableInputsFailure(),
          SyncInvalidAddressFailure() =>
            const WalletAddressNetworkMismatchFailure(),
          _ => WalletTransactionBuildFailure(failure.logCode),
        }),
      };
    } on Exception {
      return const Err(WalletTransactionBuildFailure());
    }
  }

  Future<(int, int)> getPsetSizeAndAbsoluteFees({required String pset}) async {
    return switch (await sync.liquidPsetFees(pset)) {
      Ok(:final value) => (value.discountedVsize, value.feeSat),
      Err(:final failure) => throw WalletSnapshotException(failure),
    };
  }

  Future<int> getLbtcUtxoCount({required String walletId}) async {
    final metadata = await _walletMetadataDatasource.fetch(walletId);
    if (metadata == null) {
      throw Exception('Wallet metadata not found for walletId: $walletId');
    }
    if (!metadata.isLiquid) {
      throw Exception('Wallet $walletId is not a Liquid wallet');
    }
    return _values.getLbtcUtxoCount(
      key: sync.WalletKey(id: metadata.id, network: metadata.network.shared),
    );
  }

  /// The unsigned consolidation PSETs, built and checked by sync's writer.
  /// Throws when it refuses them.
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
    final sync.ConsolidationRequest request;
    try {
      request = sync.ConsolidationRequest(
        fee: sync.SpendFeeRate(feeRate.satPerKwu),
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      );
    } on ArgumentError {
      throw const WalletSnapshotException(sync.SyncSpendRefusedFailure());
    }
    final key = sync.WalletKey(
      id: metadata.id,
      network: metadata.network.shared,
    );
    final result = switch (await _wallet(key)) {
      Ok(:final value) => await value.tx.consolidate(request),
      Err(:final failure) => Err<List<sync.UnsignedSpend>, SyncFailure>(
        failure,
      ),
    };
    return switch (result) {
      Ok(:final value) => [for (final spend in value) spend.encoded],
      Err(:final failure) => throw WalletSnapshotException(failure),
    };
  }

  Future<String> signPset({
    required String pset,
    required String walletId,
  }) async {
    final frozen = await _frozenOutpoints();
    final inputs = frozen.isEmpty
        ? <Outpoint>{}
        : switch (sync.decodeLiquidPset(pset)) {
            Ok(:final value) => {
              for (final input in value.inputs)
                (txId: input.txid, vout: input.vout),
            },
            Err(:final failure) => throw WalletSnapshotException(failure),
          };
    if (inputs.any(frozen.contains)) {
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

  /// Read from sync's store at call time; throws when it cannot answer.
  Future<Set<Outpoint>> _frozenOutpoints() => _freezes.getFrozenOutpoints();

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
    final key = sync.WalletKey(
      id: metadata.id,
      network: metadata.network.shared,
    );
    final wallet = switch (await _wallet(key)) {
      Ok(:final value) => value,
      Err(:final failure) => throw WalletSnapshotException(failure),
    };
    return switch (await wallet.tx.liquidAmountToAddress(pset, address)) {
      Ok(:final value) => value.toInt(),
      Err(:final failure) => throw WalletSnapshotException(failure),
    };
  }
}
