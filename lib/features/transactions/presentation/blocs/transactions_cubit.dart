import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

part 'transactions_cubit.freezed.dart';
part 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    String? walletId,
    bool exchangeOnly = false,
    required this._getTransactionsUsecase,
    required this._refreshTransactionLabelsUsecase,
    required this._watchStartedWalletSyncsUsecase,
    required this._watchFinishedWalletSyncsUsecase,
  }) : super(
         TransactionsState(walletId: walletId, exchangeOnly: exchangeOnly),
       ) {
    _startedSyncSubscription = _watchStartedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => emit(state.copyWith(isSyncing: true)));
    _finishedSyncSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => _onSyncFinished());
  }

  final GetTransactionsUsecase _getTransactionsUsecase;
  final RefreshTransactionLabelsUsecase _refreshTransactionLabelsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription? _startedSyncSubscription;
  StreamSubscription? _finishedSyncSubscription;
  Timer? _debounceTimer;

  /// Bumped every time [loadTxs] replaces the list, so a [refreshLabels] that
  /// started from an older snapshot can tell it lost the race and drop its
  /// result instead of reinstating stale transactions.
  int _loadGeneration = 0;

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    await Future.wait([
      _startedSyncSubscription?.cancel() ?? Future.value(),
      _finishedSyncSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  Future<void> loadTxs() async {
    try {
      // if (state.isSyncing) {
      //   return; // Already syncing, no need to fetch again
      // }
      // Load local txs from db to get latest state from tx details page updates

      emit(state.copyWith(isSyncing: true));
      final transactions = await _getTransactionsUsecase.execute(
        walletId: state.walletId,
      );

      _loadGeneration++;
      emit(
        state.copyWith(transactions: transactions, isSyncing: false, err: null),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e, isSyncing: false));
      }
    }
  }

  /// Re-reads the labels of the transactions already in state.
  Future<void> refreshLabels() async {
    final transactions = state.transactions;
    if (transactions == null || transactions.isEmpty) return;

    final generation = _loadGeneration;
    final refreshed = await _refreshTransactionLabelsUsecase.execute(
      transactions,
    );
    if (isClosed ||
        // A load landed while we were reading; its transactions are newer and
        // carry freshly read labels anyway.
        _loadGeneration != generation ||
        // Identical when no label changed.
        identical(refreshed, transactions)) {
      return;
    }

    emit(state.copyWith(transactions: refreshed));
  }

  void setFilter(TransactionsFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  Future<void> _onSyncFinished() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      loadTxs();
    });
  }
}
