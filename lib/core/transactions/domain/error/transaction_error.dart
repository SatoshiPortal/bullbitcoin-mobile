import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_error.freezed.dart';

/// Domain errors for the transaction feature.
@freezed
sealed class TransactionError with _$TransactionError {
  /// Failed to fetch a parent transaction to resolve input values.
  const factory TransactionError.fetchFailed({
    required String txid,
    String? message,
  }) = TransactionFetchFailed;

  /// An input's parent transaction was found but the referenced output
  /// index does not exist.
  const factory TransactionError.inputResolutionFailed({
    required String parentTxId,
    required int vout,
  }) = TransactionInputResolutionFailed;

  /// The transaction could not be parsed from the provided data.
  const factory TransactionError.parseFailed({String? message}) =
      TransactionParseFailed;

  /// An unexpected error occurred.
  const factory TransactionError.unexpected(String? message) =
      UnexpectedTransactionError;

  const TransactionError._();
}
