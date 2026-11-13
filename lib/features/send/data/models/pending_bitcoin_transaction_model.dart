import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_bitcoin_transaction_model.freezed.dart';

typedef PendingBitcoinRecipientModel = ({
  String recipient,
  String amount,
  bool receivesRemainder,
});

@freezed
abstract class PendingBitcoinTransactionModel
    with _$PendingBitcoinTransactionModel {
  const factory PendingBitcoinTransactionModel({
    required String id,
    required String walletId,
    required String stage,
    String? label,
    required List<PendingBitcoinRecipientModel> recipients,
    required String amountCurrencyCode,
    @Default(false) bool isSweep,
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
