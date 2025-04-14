import 'package:bb_mobile/core/wallet_transaction/domain/entities/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet_transaction_model.freezed.dart';

@freezed
sealed class WalletTransactionModel with _$WalletTransactionModel {
  const factory WalletTransactionModel.bitcoin({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    int? confirmationTimestamp,
  }) = BitcoinWalletTransactionModel;
  const factory WalletTransactionModel.liquid({
    required String txId,
    required bool isIncoming,
    required int amountSat,
    required int feeSat,
    int? confirmationTimestamp,
  }) = LiquidWalletTransactionModel;
  const WalletTransactionModel._();

  WalletTransaction toEntity({required String origin}) {
    return when(
      bitcoin: (
        String txId,
        bool isIncoming,
        int amountSat,
        int feeSat,
        int? confirmationTimestamp,
      ) =>
          WalletTransaction.bitcoin(
        origin: origin,
        direction: isIncoming
            ? WalletTransactionDirection.incoming
            : WalletTransactionDirection.outgoing,
        status: confirmationTimestamp == null
            ? WalletTransactionStatus.pending
            : WalletTransactionStatus.confirmed,
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
        origin: origin,
        direction: isIncoming
            ? WalletTransactionDirection.incoming
            : WalletTransactionDirection.outgoing,
        status: confirmationTimestamp == null
            ? WalletTransactionStatus.pending
            : WalletTransactionStatus.confirmed,
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
