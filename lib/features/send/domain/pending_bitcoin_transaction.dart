import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy_path.dart';

enum PendingBitcoinTransactionStage { draft, needsSignatures, readyToBroadcast }

final class PendingBitcoinTransaction {
  final String id;
  final String walletId;
  final PendingBitcoinTransactionStage stage;
  final String? label;
  final String recipient;
  final String amount;
  final String amountCurrencyCode;
  final bool sendMax;
  final FeeSelection feeSelection;
  final NetworkFee? customFee;
  final bool replaceByFee;
  final bool payjoinOptedOut;
  final Set<String> selectedOutpoints;
  final BitcoinPolicySelection policySelection;
  final String? psbt;
  final String? finalTransaction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final bool isConflict;
  final bool isPolicyReady;
  final int signersNeeded;

  PendingBitcoinTransaction({
    required this.id,
    required this.walletId,
    required this.stage,
    this.label,
    required this.recipient,
    required this.amount,
    required this.amountCurrencyCode,
    required this.sendMax,
    required this.feeSelection,
    this.customFee,
    required this.replaceByFee,
    this.payjoinOptedOut = false,
    Set<String> selectedOutpoints = const {},
    this.policySelection = const BitcoinPolicySelection.empty(),
    this.psbt,
    this.finalTransaction,
    required this.createdAt,
    required this.updatedAt,
    this.revision = 0,
    this.isConflict = false,
    this.isPolicyReady = true,
    this.signersNeeded = 0,
  }) : selectedOutpoints = Set.unmodifiable(selectedOutpoints) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id');
    if (walletId.isEmpty) throw ArgumentError.value(walletId, 'walletId');
    if (stage != PendingBitcoinTransactionStage.draft) {
      if (psbt?.trim().isEmpty ?? true) {
        throw ArgumentError('A signing transaction must contain a PSBT');
      }
      if (recipient.trim().isEmpty) {
        throw ArgumentError('A signing transaction must contain a recipient');
      }
      final amountSat = BigInt.tryParse(amount);
      if (amountSat == null || amountSat <= BigInt.zero) {
        throw ArgumentError('A signing transaction must contain an amount');
      }
      if (amountCurrencyCode.isEmpty) {
        throw ArgumentError(
          'A signing transaction must contain an amount currency',
        );
      }
      if (finalTransaction?.trim().isEmpty ?? false) {
        throw ArgumentError.value(finalTransaction, 'finalTransaction');
      }
    }
    if (signersNeeded < 0) {
      throw ArgumentError.value(signersNeeded, 'signersNeeded');
    }
    if (revision < 0) throw ArgumentError.value(revision, 'revision');
    if (feeSelection == FeeSelection.custom && customFee == null) {
      throw ArgumentError('A custom fee selection must contain a fee');
    }
    if (customFee case AbsoluteFee(:final sats) when sats <= 0) {
      throw ArgumentError.value(sats, 'customFee');
    }
    if (customFee case RelativeFee(:final satPerKwu) when satPerKwu <= 0) {
      throw ArgumentError.value(satPerKwu, 'customFee');
    }
  }

  bool get isDraft => stage == PendingBitcoinTransactionStage.draft;
  bool get isReadyToBroadcast =>
      stage == PendingBitcoinTransactionStage.readyToBroadcast;

  PendingBitcoinTransaction copyWith({
    PendingBitcoinTransactionStage? stage,
    String? label,
    bool clearLabel = false,
    String? recipient,
    String? amount,
    String? amountCurrencyCode,
    bool? sendMax,
    FeeSelection? feeSelection,
    NetworkFee? customFee,
    bool clearCustomFee = false,
    bool? replaceByFee,
    bool? payjoinOptedOut,
    Set<String>? selectedOutpoints,
    BitcoinPolicySelection? policySelection,
    String? psbt,
    bool clearPsbt = false,
    String? finalTransaction,
    bool clearFinalTransaction = false,
    DateTime? updatedAt,
    int? revision,
    bool? isConflict,
    bool? isPolicyReady,
    int? signersNeeded,
  }) => PendingBitcoinTransaction(
    id: id,
    walletId: walletId,
    stage: stage ?? this.stage,
    label: clearLabel ? null : label ?? this.label,
    recipient: recipient ?? this.recipient,
    amount: amount ?? this.amount,
    amountCurrencyCode: amountCurrencyCode ?? this.amountCurrencyCode,
    sendMax: sendMax ?? this.sendMax,
    feeSelection: feeSelection ?? this.feeSelection,
    customFee: clearCustomFee ? null : customFee ?? this.customFee,
    replaceByFee: replaceByFee ?? this.replaceByFee,
    payjoinOptedOut: payjoinOptedOut ?? this.payjoinOptedOut,
    selectedOutpoints: selectedOutpoints ?? this.selectedOutpoints,
    policySelection: policySelection ?? this.policySelection,
    psbt: clearPsbt ? null : psbt ?? this.psbt,
    finalTransaction: clearFinalTransaction
        ? null
        : finalTransaction ?? this.finalTransaction,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    revision: revision ?? this.revision,
    isConflict: isConflict ?? this.isConflict,
    isPolicyReady: isPolicyReady ?? this.isPolicyReady,
    signersNeeded: signersNeeded ?? this.signersNeeded,
  );
}

final class PendingBitcoinTransactionSnapshot {
  final List<PendingBitcoinTransaction> transactions;
  final int invalidCount;

  PendingBitcoinTransactionSnapshot({
    required Iterable<PendingBitcoinTransaction> transactions,
    this.invalidCount = 0,
  }) : transactions = List.unmodifiable(transactions) {
    if (invalidCount < 0) {
      throw ArgumentError.value(invalidCount, 'invalidCount');
    }
  }
}
