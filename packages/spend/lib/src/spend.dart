import 'dart:typed_data';

import 'package:ark/funding.dart' show ArkFundingSigningGuard;
import 'package:fees/fees.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'domain/spend_catalog.dart';
import 'domain/spend_failure.dart';

part 'spend_operations.dart';
part 'spend_testing.dart';

typedef SpendBroadcastReceipt = ({String txid, bool guarded, bool durable});
typedef BitcoinSpendPreview = ({PreparedBitcoinSpend prepared, Sats fee});

final class PreparedBitcoinSpend {
  final UnsignedSpend? _native;
  final String unsignedPsbt;
  final Sats fee;
  final int txSize;
  final bool isToSelf;
  final List<Sats> recipientAmountsSat;

  PreparedBitcoinSpend._(
    this._native, {
    required this.unsignedPsbt,
    required this.fee,
    required this.txSize,
    required this.isToSelf,
    required List<Sats> recipientAmountsSat,
  }) : recipientAmountsSat = List.unmodifiable(recipientAmountsSat);
}

final class PreparedLiquidSpend {
  final UnsignedSpend? _native;
  final String unsignedPset;
  final Sats fee;
  final Sats amountSent;

  const PreparedLiquidSpend._(
    this._native, {
    required this.unsignedPset,
    required this.fee,
    required this.amountSent,
  });
}

final class SignedBitcoinSpend {
  final SignedSpend? _native;
  final String signedTransaction;
  final int txSize;

  const SignedBitcoinSpend._(this._native, this.signedTransaction, this.txSize);
}

final class SignedLiquidSpend {
  final SignedSpend? _native;
  final String signedPset;

  const SignedLiquidSpend._(this._native, this.signedPset);
}

final class PreparedLiquidConsolidation {
  final List<UnsignedSpend>? _batches;
  final int transactionCount;
  final Sats totalFee;

  const PreparedLiquidConsolidation._(
    this._batches,
    this.transactionCount,
    this.totalFee,
  );
}

/// The original transaction and exact inputs reserved by a Payjoin session.
/// Spend does not broadcast this value.
abstract final class PayjoinSpendHandoff {
  String get unsignedPsbt;
  WalletKey get wallet;
  Set<Outpoint> get inputs;
}

abstract interface class Spend {
  static Spend open({
    required WalletNativeRuntime sync,
    required Secrets secrets,
    required ArkFundingSigningGuard arkFunding,
    required SpendCatalog catalog,
  }) => _Spend(sync, secrets, arkFunding, catalog);

  @useResult
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  });

  @useResult
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
  });

  @useResult
  Future<Result<void, SpendFailure>> validateBitcoinSelection({
    required String walletId,
    Set<Outpoint>? selectedInputs,
  });

  @useResult
  Future<Result<BitcoinSpendPreview?, SpendFailure>> previewBitcoinFee({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  });

  @useResult
  Future<Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>
  previewBitcoinFeePresets({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required FeeOptions presets,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  });

  @useResult
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  });

  @useResult
  Future<Result<SignedLiquidSpend, SpendFailure>> signLiquid({
    required PreparedLiquidSpend prepared,
  });

  @useResult
  Future<Result<SignedBitcoinSpend, SpendFailure>> verifySignedBitcoin({
    required PreparedBitcoinSpend prepared,
    required String signedTransaction,
    required bool isPsbt,
  });

  /// Checks an external signature against its actual exported PSBT. Does not
  /// create a wallet-bound spend or grant permission to broadcast.
  @useResult
  Result<void, SpendFailure> verifyExternalBitcoin({
    required String unsignedPsbt,
    required String signedTransaction,
    required bool isPsbt,
  });

  @useResult
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  );

  @useResult
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  );

  /// Replays only the stored PSET for an already-pinned Liquid payment.
  @useResult
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeLiquidPayin({
    required String signedPset,
    required String walletId,
    required LiquidNetwork network,
    required String address,
    required Sats amount,
  });

  /// Replays the signed bytes already pinned to this Bitcoin payment.
  @useResult
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeBitcoinPayin({
    required String signedPsbt,
    required String walletId,
    required BitcoinNetwork network,
    required String address,
    required Sats amount,
    bool isPsbt = true,
  });

  @useResult
  Future<Result<String, SpendFailure>> broadcastImportedBitcoin({
    required String transaction,
    required BitcoinNetwork network,
    required bool isPsbt,
  });

  @useResult
  Future<Result<PayjoinSpendHandoff, SpendFailure>> handOffToPayjoin(
    PreparedBitcoinSpend prepared, {
    required WalletKey wallet,
    required String sessionId,
    required String signedPsbt,
    required Future<void> Function() persist,
  });

  @useResult
  Future<Result<void, SpendFailure>> verifyOriginalBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
  });

  @useResult
  Future<Result<SpendBroadcastReceipt, SpendFailure>> replaceBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
    required RelativeFee newFeeRate,
  });

  @useResult
  Future<Result<int, SpendFailure>> countLiquidCoins(String walletId);

  @useResult
  Future<Result<bool, SpendFailure>> needsLiquidConsolidation(
    String walletId, {
    required int highUtxoThreshold,
  });

  @useResult
  Future<Result<PreparedLiquidConsolidation, SpendFailure>>
  prepareLiquidConsolidation(
    String walletId, {
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  });

  @useResult
  Future<Result<List<String>, SpendFailure>> submitLiquidConsolidation(
    PreparedLiquidConsolidation prepared,
  );
}
