import 'package:bb_mobile/features/transactions/domain/usecases/find_transaction_owner_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_explored_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart' show Err, Ok;

class TransactionExplorerCubit extends Cubit<TransactionExplorerState> {
  final GetExploredTransactionUsecase _getExploredTransactionUsecase;
  final FindTransactionOwnerUsecase _findTransactionOwnerUsecase;

  TransactionExplorerCubit({
    required String txid,
    required this._getExploredTransactionUsecase,
    required this._findTransactionOwnerUsecase,
  }) : super(TransactionExplorerState(txid: txid));

  Future<void> load() async {
    await Future.wait([_loadOwnership(), _loadTransaction()]);
  }

  Future<void> _loadOwnership() async {
    final result = await _findTransactionOwnerUsecase.execute(state.txid);
    if (isClosed) return;
    emit(
      state.withOwnership(switch (result) {
        Ok(:final value) => TransactionOwnershipKnown(value),
        Err() => const TransactionOwnershipUnavailable(),
      }),
    );
  }

  Future<void> _loadTransaction() async {
    if (state.isLoadingTransaction) return;
    emit(state.withTransactionLoading());
    final result = await _getExploredTransactionUsecase.execute(state.txid);
    if (isClosed) return;
    emit(switch (result) {
      Ok(:final value) => state.withTransaction(value),
      Err(:final failure) => state.withFailure(failure),
    });
  }
}
