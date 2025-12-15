import 'package:bb_mobile/core_deprecated/wallet/data/models/transaction_input_model.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/models/transaction_output_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction_model.freezed.dart';

@freezed
sealed class WalletTransactionModel with _$WalletTransactionModel {
  const factory WalletTransactionModel({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    required int vsize,
    required List<TransactionInputModel> inputs,
    required List<TransactionOutputModel> outputs,
    required bool isLiquid,
    required bool isTestnet,
    required bool isRbf,
    int? confirmationTimestamp,
    String? unblindedUrl,
    @Default(false) bool isToSelf,
  }) = _WalletTransactionModel;
  const WalletTransactionModel._();
}
