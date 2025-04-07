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
    required String address,
    required TransactionDirection direction,
    required TransactionStatus status,
    @Default('') String txId,
    @Default(0) int amountSat,
    @Default(0) int feeSat,
    @Default('') String label,
    int? timestamp,
    @Default('') String payjoinId,
    @Default('') String swapId,
    // @Default('') String exchangeId, // If related to a buy or sell
  }) = BitcoinTransaction;
  const factory Transaction.liquid({
    required String walletId,
    required String address,
    required TransactionDirection direction,
    required TransactionStatus status,
    @Default('') String txId,
    @Default(0) int amountSat,
    @Default(0) int feeSat,
    @Default('') String label,
    int? timestamp,
    @Default('') String swapId,
    // @Default('') String exchangeId, // If related to a buy or sell
  }) = LiquidTransaction;
  const Transaction._();
}
