import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart'
    show SpendWallet;
import 'package:primitives/primitives.dart' show Err, Ok, Outpoint, Result;
import 'package:sync/sync.dart' show WalletSnapshotException;
import 'package:sync/sync.dart' as sync;

/// Liquid spends through `wallet.tx`, and the PSET facts the app reads.
/// No native handle is held here.
///
/// ⚠️ Liquid has no spend guard: its broadcast checks freezes only, and a
/// concurrent spend of the same coins is not prevented.
class LwkWalletDatasource {
  final SpendWallet _wallet;

  LwkWalletDatasource({required this._wallet});

  /// One build by the writer. With [drain], every spendable coin goes to
  /// [address]; [selectedInputs] are spent and no other coin is.
  Future<Result<sync.UnsignedSpend, sync.SyncFailure>> buildPset({
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    required WalletModel wallet,
    Set<Outpoint>? selectedInputs,
  }) async {
    final sync.LiquidSpendRequest request;
    try {
      request = sync.LiquidSpendRequest(
        address: address,
        amountSat: drain ? null : amountSat,
        fee: sync.SpendFeeRate(feeRate.satPerKwu),
        selected: selectedInputs,
      );
    } on ArgumentError {
      return const Err(sync.SyncSpendRefusedFailure());
    }
    if (!drain && amountSat == null) {
      return const Err(sync.SyncSpendRefusedFailure());
    }
    return (await _wallet(wallet.id)).tx.build(request);
  }

  /// The unsigned consolidation batches, each checked by the writer; empty
  /// when the wallet holds no more than [highUtxoThreshold] coins.
  ///
  /// KNOWN LIMITATION (privacy, not fund safety): each batch drains to the
  /// next unused address natively, with no durable reservation; two rounds
  /// before a sync can reuse an address.
  Future<Result<List<sync.UnsignedSpend>, sync.SyncFailure>> consolidate({
    required WalletModel wallet,
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final sync.ConsolidationRequest request;
    try {
      request = sync.ConsolidationRequest(
        fee: sync.SpendFeeRate(feeRate.satPerKwu),
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      );
    } on ArgumentError {
      return const Err(sync.SyncSpendRefusedFailure());
    }
    return (await _wallet(wallet.id)).tx.consolidate(request);
  }

  Set<Outpoint> getPsetInputs(String pset) => switch (sync.decodeLiquidPset(
    pset,
  )) {
    Ok(:final value) => {
      for (final input in value.inputs) (txId: input.txid, vout: input.vout),
    },
    Err(:final failure) => throw WalletSnapshotException(failure),
  };

  Future<(int, int)> decodeAbsoluteFeesFromPset(String pset) async =>
      switch (await sync.liquidPsetFees(pset)) {
        Ok(:final value) => (value.discountedVsize, value.feeSat),
        Err(:final failure) => throw WalletSnapshotException(failure),
      };

  /// Policy-asset outputs paid to [address], excluding change and fees.
  Future<int> getAmountSentToAddress(
    String pset,
    String address, {
    required WalletModel wallet,
  }) async =>
      switch (await (await _wallet(wallet.id)).tx
          .liquidAmountToAddress(pset, address)) {
        Ok(:final value) => value.toInt(),
        Err(:final failure) => throw WalletSnapshotException(failure),
      };
}
