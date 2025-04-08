import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction.freezed.dart';

enum TransactionDirection {
  incoming,
  outgoing,
}

enum TransactionStatus {
  pending,
  confirmed,
}

@freezed
sealed class Transaction with _$Transaction {
  const factory Transaction.bitcoin({
    required String walletId,
    required TransactionDirection direction,
    required TransactionStatus status,
    @Default('') String txId,
    @Default(0) int amountSat,
    @Default(0) int feeSat,
    DateTime? confirmationTime,
  }) = BitcoinTransaction;
  const factory Transaction.liquid({
    required String walletId,
    required TransactionDirection direction,
    required TransactionStatus status,
    @Default('') String txId,
    @Default(0) int amountSat,
    @Default(0) int feeSat,
    DateTime? confirmationTime,
  }) = LiquidTransaction;
  const Transaction._();
}
