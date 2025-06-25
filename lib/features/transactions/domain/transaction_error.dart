import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_error.freezed.dart';

@freezed
sealed class TransactionError with _$TransactionError implements Exception {
  const factory TransactionError.notFound() = TransactionNotFoundError;

  const TransactionError._();
}
