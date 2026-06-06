import 'package:freezed_annotation/freezed_annotation.dart';

part 'domain_errors.freezed.dart';

/// Errors raised while building a [ReviewableTransaction].
///
/// Discrete variants per failure mode — the presentation layer never sees
/// a foreign error type. Port-layer errors are mapped into these by the
/// usecase at the boundary.
@freezed
sealed class TransactionReviewError with _$TransactionReviewError {
  /// Failed to fetch a parent transaction needed to resolve an input value.
  const factory TransactionReviewError.fetchFailed({
    required String txid,
    String? message,
  }) = TransactionReviewFetchFailed;

  /// No Electrum servers configured / reachable for the active network.
  const factory TransactionReviewError.noServersAvailable({String? network}) =
      TransactionReviewNoServersAvailable;

  /// An input's parent transaction was found but the referenced output
  /// index does not exist.
  const factory TransactionReviewError.inputResolutionFailed({
    required String parentTxId,
    required int vout,
  }) = TransactionReviewInputResolutionFailed;

  /// An unexpected error escaped from the usecase or cubit.
  const factory TransactionReviewError.unexpected(String? message) =
      UnexpectedTransactionReviewError;

  const TransactionReviewError._();
}
