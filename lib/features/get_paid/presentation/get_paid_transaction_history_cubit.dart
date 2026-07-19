import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/domain/list_get_paid_transactions_usecase.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class GetPaidTransactionHistoryCubit
    extends Cubit<GetPaidTransactionHistoryState> {
  static const int pageSize = 20;

  final ListGetPaidTransactionsUsecase _listTransactions;
  int _generation = 0;

  GetPaidTransactionHistoryCubit({required this._listTransactions})
    : super(const GetPaidTransactionHistoryState());

  Future<void> load() => refresh();

  Future<void> refresh() async {
    final generation = ++_generation;
    emit(
      const GetPaidTransactionHistoryState(
        status: GetPaidTransactionHistoryStatus.loading,
      ),
    );
    final result = await _listTransactions.execute(cursor: '', limit: pageSize);
    if (_isStale(generation)) return;
    switch (result) {
      case Ok(:final value):
        emit(
          GetPaidTransactionHistoryState(
            status: GetPaidTransactionHistoryStatus.loaded,
            transactions: value.transactions,
            nextCursor: value.nextCursor,
          ),
        );
      case Err(:final failure):
        emit(
          GetPaidTransactionHistoryState(
            status: GetPaidTransactionHistoryStatus.failure,
            failure: failure,
          ),
        );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.status != GetPaidTransactionHistoryStatus.loaded ||
        cursor == null ||
        state.isLoadingMore) {
      return;
    }

    final generation = _generation;
    emit(state.copyWith(isLoadingMore: true, loadMoreFailed: false));
    final result = await _listTransactions.execute(
      cursor: cursor,
      limit: pageSize,
    );
    if (_isStale(generation)) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            transactions: _mergeByStableKey(
              state.transactions,
              value.transactions,
            ),
            nextCursor: value.nextCursor,
            clearNextCursor: value.nextCursor == null,
            isLoadingMore: false,
            loadMoreFailed: false,
          ),
        );
      case Err():
        emit(state.copyWith(isLoadingMore: false, loadMoreFailed: true));
    }
  }

  List<GetPaidTransaction> _mergeByStableKey(
    List<GetPaidTransaction> current,
    List<GetPaidTransaction> next,
  ) {
    final merged = current.toList();
    final indexByKey = <String, int>{
      for (var index = 0; index < merged.length; index++)
        merged[index].stableKey: index,
    };
    for (final transaction in next) {
      final existing = indexByKey[transaction.stableKey];
      if (existing == null) {
        indexByKey[transaction.stableKey] = merged.length;
        merged.add(transaction);
      } else {
        merged[existing] = transaction;
      }
    }
    return List.unmodifiable(merged);
  }

  bool _isStale(int generation) => isClosed || generation != _generation;
}
