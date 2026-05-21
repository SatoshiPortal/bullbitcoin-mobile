import 'package:bb_mobile/features/broadcast_signed_tx/domain/domain_errors.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/reviewable_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_review_state.freezed.dart';

/// State for the [TransactionReviewCubit].
@freezed
sealed class TransactionReviewState with _$TransactionReviewState {
  /// Initial state before any transaction is loaded.
  const factory TransactionReviewState.initial() = TransactionReviewInitial;

  /// Loading state while resolving input values for an external transaction.
  const factory TransactionReviewState.loading() = TransactionReviewLoading;

  /// Successfully resolved [ReviewableTransaction] ready to render.
  const factory TransactionReviewState.loaded({
    required ReviewableTransaction transaction,
  }) = TransactionReviewLoaded;

  /// Resolution failed; carries a [TransactionReviewError] for the UI to map.
  const factory TransactionReviewState.error({
    required TransactionReviewError error,
  }) = TransactionReviewErrorState;
}
