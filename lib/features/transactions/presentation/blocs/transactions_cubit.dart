import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/usecases/get_transactions_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transactions_cubit.freezed.dart';
part 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  static final Map<String?, List<Transaction>> _transactionsCache = {};
  static final Set<TransactionsCubit> _activeCubits = {};

  TransactionsCubit({
    String? walletId,
    required GetTransactionsUsecase getTransactionsUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
  }) : _getTransactionsUsecase = getTransactionsUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       super(TransactionsState(walletId: walletId)) {
    _activeCubits.add(this);
    _startedSyncSubscription = _watchStartedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => emit(state.copyWith(isSyncing: true)));
    _finishedSyncSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => _onSyncFinished());

    final cachedTransactions = _transactionsCache[walletId];
    if (cachedTransactions != null) {
      emit(state.copyWith(transactions: cachedTransactions));
    }
  }

  final GetTransactionsUsecase _getTransactionsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription? _startedSyncSubscription;
  StreamSubscription? _finishedSyncSubscription;
  Timer? _debounceTimer;

  @override
  Future<void> close() async {
    _activeCubits.remove(this);
    await Future.wait([
      _startedSyncSubscription?.cancel() ?? Future.value(),
      _finishedSyncSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  Future<void> loadTxs() async {
    try {
      final cachedTransactions = _transactionsCache[state.walletId];
      if (cachedTransactions != null) {
        emit(
          state.copyWith(
            transactions: cachedTransactions,
            isSyncing: true,
            err: null,
          ),
        );
      } else {
        emit(state.copyWith(isSyncing: true));
      }

      final transactions = await _getTransactionsUsecase.execute(
        walletId: state.walletId,
      );

      _transactionsCache[state.walletId] = transactions;

      emit(
        state.copyWith(transactions: transactions, isSyncing: false, err: null),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e, isSyncing: false));
      }
    }
  }

  static void updateTransactionInCache(
    Transaction updatedTransaction, {
    required String? walletId,
  }) {
    final transactions = _transactionsCache[walletId];
    if (transactions == null) return;

    final index = transactions.indexWhere((tx) {
      if (tx.walletTransaction?.txId ==
          updatedTransaction.walletTransaction?.txId) {
        return true;
      }
      if (tx.swap?.id == updatedTransaction.swap?.id) {
        return true;
      }
      if (tx.payjoin?.id == updatedTransaction.payjoin?.id) {
        return true;
      }
      if (tx.order?.orderId == updatedTransaction.order?.orderId) {
        return true;
      }
      return false;
    });

    if (index != -1) {
      final updatedTransactions = List<Transaction>.from(transactions);
      updatedTransactions[index] = updatedTransaction;
      _transactionsCache[walletId] = updatedTransactions;

      for (final cubit in _activeCubits.toList()) {
        if (!cubit.isClosed && cubit.state.walletId == walletId) {
          cubit.emit(cubit.state.copyWith(transactions: updatedTransactions));
        }
      }
    }
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
