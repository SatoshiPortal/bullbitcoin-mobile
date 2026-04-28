import 'package:bb_mobile/core/transactions/domain/entity/transaction_entity.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_state.freezed.dart';

/// State for the [TransactionCubit].
@freezed
sealed class TransactionState with _$TransactionState {
  /// Initial state before any transaction is loaded.
  const factory TransactionState.initial() = TransactionInitial;

  /// Loading state while resolving input values (for external transactions).
  const factory TransactionState.loading() = TransactionLoading;

  /// Successfully loaded transaction entity with all data resolved.
  const factory TransactionState.loaded({required TransactionEntity entity}) =
      TransactionLoaded;

  /// Error state when transaction loading or input resolution fails.
  const factory TransactionState.error({required TransactionError error}) =
      TransactionErrorState;
}
