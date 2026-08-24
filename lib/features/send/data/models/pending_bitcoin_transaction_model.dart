import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_bitcoin_transaction_model.freezed.dart';

@freezed
abstract class PendingBitcoinTransactionModel
    with _$PendingBitcoinTransactionModel {
  const factory PendingBitcoinTransactionModel({
    required String id,
    required String walletId,
    required String stage,
    String? label,
    required String recipient,
    required String amount,
    required String amountCurrencyCode,
    required bool sendMax,
    required String feeSelection,
    String? customFeeKind,
    int? customFeeValue,
    required bool replaceByFee,
    @Default(false) bool payjoinOptedOut,
    required Set<String> selectedOutpoints,
    required Map<String, List<int>> policyChoices,
    String? psbt,
    String? finalTransaction,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int revision,
  }) = _PendingBitcoinTransactionModel;
}
