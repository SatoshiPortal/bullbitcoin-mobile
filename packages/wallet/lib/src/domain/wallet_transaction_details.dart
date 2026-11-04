import 'transaction_input_details.dart';
import 'transaction_output_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction_details.freezed.dart';

@freezed
sealed class WalletTransactionDetails with _$WalletTransactionDetails {
  const factory WalletTransactionDetails({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    required int vsize,
    required List<TransactionInputDetails> inputs,
    required List<TransactionOutputDetails> outputs,
    required bool isLiquid,
    required bool isTestnet,
    required bool isRbf,
    int? confirmationTimestamp,
    String? unblindedUrl,
    @Default(false) bool isToSelf,
  }) = _WalletTransactionDetails;
  const WalletTransactionDetails._();
}
