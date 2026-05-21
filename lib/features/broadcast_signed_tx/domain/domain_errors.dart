import 'package:bb_mobile/core/transactions/domain/domain_errors.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'domain_errors.freezed.dart';

/// Errors raised while building a [ReviewableTransaction].
///
/// Wraps lower-layer [TransactionPortError]s at the boundary so the
/// presentation layer never sees a foreign error type.
@freezed
sealed class TransactionReviewError with _$TransactionReviewError {
  /// An input's parent transaction was found but the referenced output
  /// index does not exist.
  const factory TransactionReviewError.inputResolutionFailed({
    required String parentTxId,
    required int vout,
  }) = TransactionReviewInputResolutionFailed;

  /// A port-layer failure surfaced while resolving inputs. The inner
  /// [TransactionPortError] preserves the granular reason for the UI to
  /// render context-specific messaging.
  const factory TransactionReviewError.portFailure({
    required TransactionPortError portError,
  }) = TransactionReviewPortFailure;

  /// An unexpected error escaped from the usecase or cubit.
  const factory TransactionReviewError.unexpected(String? message) =
      UnexpectedTransactionReviewError;

  const TransactionReviewError._();
}
