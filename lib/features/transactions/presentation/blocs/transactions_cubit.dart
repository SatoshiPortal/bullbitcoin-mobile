import 'package:bb_mobile/features/transactions/domain/usecases/watch_transaction_reloads_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/watch_wallet_revisions_usecase.dart';
import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_transactions_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/refresh_transaction_labels_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

part 'transactions_cubit.freezed.dart';
part 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    WatchWalletRevisionsUsecase? watchWalletRevisionsUsecase,
    WatchTransactionReloadsUsecase? watchTransactionReloadsUsecase,
    String? walletId,
    bool exchangeOnly = false,
    required this._getTransactionsUsecase,
    required this._refreshTransactionLabelsUsecase,
    required this._watchStartedWalletSyncsUsecase,
    required this._watchFinishedWalletSyncsUsecase,
  }) : super(
         TransactionsState(walletId: walletId, exchangeOnly: exchangeOnly),
       ) {
    if (walletId == null) {
      _revisionsSubscription = watchTransactionReloadsUsecase?.execute().listen(
        (update) {
          if (_closing) return;
          switch (update) {
            case TransactionHistoryUpdate.syncing:
              emit(state.copyWith(isSyncing: true));
            case TransactionHistoryUpdate.reload:
              _scheduleReload(debounce: false);
          }
        },
      );
      return;
    }
    _startedSyncSubscription = _watchStartedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) {
          if (!_closing) emit(state.copyWith(isSyncing: true));
        });
    _revisionsSubscription = watchWalletRevisionsUsecase
        ?.execute(walletId: walletId)
        .listen((_) => _scheduleReload());
    _finishedSyncSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => _scheduleReload());
  }

  final GetTransactionsUsecase _getTransactionsUsecase;
  final RefreshTransactionLabelsUsecase _refreshTransactionLabelsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription? _startedSyncSubscription;
  StreamSubscription? _finishedSyncSubscription;
  StreamSubscription? _revisionsSubscription;
  Timer? _debounceTimer;
  Future<void>? _loadFuture;
  bool _reloadPending = false;
  bool _closing = false;
  int _reloadDeferrals = 0;

  /// Bumped every time [loadTxs] replaces the list, so a [refreshLabels] that
  /// started from an older snapshot can tell it lost the race and drop its
  /// result instead of reinstating stale transactions.
  int _loadGeneration = 0;

  @override
  Future<void> close() async {
    _closing = true;
    _debounceTimer?.cancel();
    await _revisionsSubscription?.cancel();
    await Future.wait([
      _startedSyncSubscription?.cancel() ?? Future.value(),
      _finishedSyncSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  /// Holds stream-triggered reads until the pull's full refresh has settled.
  void deferReloads() {
    _reloadDeferrals++;
    _debounceTimer?.cancel();
  }

  /// A read already active before the pull cannot satisfy its final reload.
  Future<void> resumeReloads() async {
    try {
      await _loadFuture;
    } finally {
      _reloadDeferrals--;
      if (_reloadDeferrals == 0) await loadTxs();
    }
  }

  Future<void> loadTxs() {
    _debounceTimer?.cancel();
    if (_closing) return Future.value();
    final active = _loadFuture;
    if (active != null) return active;
    if (_reloadDeferrals > 0) return Future.value();
    return _loadFuture = _loadUntilSettled().whenComplete(() {
      _loadFuture = null;
    });
  }

  Future<void> _loadUntilSettled() async {
    do {
      // Only invalidations received before this read are acknowledged here.
      _reloadPending = false;
      await _loadTxs();
    } while (_reloadPending && !_closing && _reloadDeferrals == 0);
  }

  Future<void> _loadTxs() async {
    // Load local txs from db to get latest state from tx details page updates
    emit(state.copyWith(isSyncing: true));

    final result = await _getTransactionsUsecase.execute(
      walletId: state.walletId,
    );
    if (_closing) return;

    switch (result) {
      case Ok(:final value):
        _loadGeneration++;
        emit(
          state.copyWith(transactions: value, isSyncing: false, failure: null),
        );
      case Err(:final failure):
        emit(state.copyWith(failure: failure, isSyncing: false));
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
    if (_closing ||
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

  void _scheduleReload({bool debounce = true}) {
    if (_closing) return;
    _reloadPending = true;
    _debounceTimer?.cancel();
    if (_reloadDeferrals > 0 || _loadFuture != null) return;
    if (debounce) {
      _debounceTimer = Timer(const Duration(seconds: 3), loadTxs);
    } else {
      unawaited(loadTxs());
    }
  }
}
