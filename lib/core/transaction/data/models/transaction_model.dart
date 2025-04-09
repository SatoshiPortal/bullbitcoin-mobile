import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_model.freezed.dart';

@freezed
sealed class TransactionModel with _$TransactionModel {
  const factory TransactionModel.bitcoin({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    int? confirmationTimestamp,
  }) = BitcoinTransactionModel;
  const factory TransactionModel.liquid({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    int? confirmationTimestamp,
  }) = LiquidTransactionModel;
  const TransactionModel._();

  WalletTransaction toEntity({required String walletId}) {
    return when(
      bitcoin: (
        String txId,
        bool isIncoming,
        int amountSat,
        int feeSat,
        int? confirmationTimestamp,
      ) =>
          WalletTransaction.bitcoin(
        walletId: walletId,
        direction: isIncoming
            ? TransactionDirection.incoming
            : TransactionDirection.outgoing,
        status: confirmationTimestamp == null
            ? TransactionStatus.pending
            : TransactionStatus.confirmed,
        txId: txId,
        amountSat: amountSat,
        feeSat: feeSat,
        confirmationTime: confirmationTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(confirmationTimestamp * 1000)
            : null,
      ),
      liquid: (
        String txId,
        bool isIncoming,
        int amountSat,
        int feeSat,
        int? confirmationTimestamp,
      ) =>
          WalletTransaction.liquid(
        walletId: walletId,
        direction: isIncoming
            ? TransactionDirection.incoming
            : TransactionDirection.outgoing,
        status: confirmationTimestamp == null
            ? TransactionStatus.pending
            : TransactionStatus.confirmed,
        txId: txId,
        amountSat: amountSat,
        feeSat: feeSat,
        confirmationTime: confirmationTimestamp != null
            ? DateTime.fromMillisecondsSinceEpoch(confirmationTimestamp * 1000)
            : null,
      ),
    );
  }
}
