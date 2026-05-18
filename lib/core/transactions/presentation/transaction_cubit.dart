import 'package:bb_mobile/core/transactions/application/build_transaction_usecase.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction_entity.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/transactions/presentation/transaction_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Cubit managing the state of a transaction being reviewed.
///
/// Supports two entry points:
/// - [loadFromTransaction] — for external transactions (PSBT/HEX),
///   resolves input values asynchronously via Electrum.
/// - [setEntity] — for pre-built [TransactionEntity] instances,
///   sets the entity directly without async resolution.
class TransactionCubit extends Cubit<TransactionState> {
  final BuildTransactionUsecase _buildTransactionUsecase;

  TransactionCubit({required BuildTransactionUsecase buildTransactionUsecase})
    : _buildTransactionUsecase = buildTransactionUsecase,
      super(const TransactionState.initial());

  /// Load and resolve an external transaction (from PSBT or HEX).
  ///
  /// This is async because it needs to fetch parent transactions
  /// via Electrum to resolve input values.
  Future<void> loadFromTransaction(Transaction tx) async {
    if (state is TransactionLoading) return;
    emit(const TransactionState.loading());
    try {
      final entity = await _buildTransactionUsecase.executeFromTransaction(tx);
      emit(TransactionState.loaded(entity: entity));
    } on TransactionError catch (e) {
      emit(TransactionState.error(error: e));
    } catch (e) {
      emit(
        TransactionState.error(
          error: TransactionError.unexpected(e.toString()),
        ),
      );
    }
  }

  /// Directly set a pre-built [TransactionEntity].
  ///
  /// Useful when the entity has already been constructed elsewhere.
  void setEntity(TransactionEntity entity) {
    emit(TransactionState.loaded(entity: entity));
  }
}
