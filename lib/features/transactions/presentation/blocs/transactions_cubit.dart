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
  TransactionsCubit({
    String? walletId,
    required GetTransactionsUsecase getTransactionsUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
  }) : _getTransactionsUsecase = getTransactionsUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       super(TransactionsState(walletId: walletId)) {
    _startedSyncSubscription = _watchStartedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => emit(state.copyWith(isSyncing: true)));
    _finishedSyncSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => _onSyncFinished());
  }

  final GetTransactionsUsecase _getTransactionsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;

  StreamSubscription? _startedSyncSubscription;
  StreamSubscription? _finishedSyncSubscription;
  Timer? _debounceTimer;

  @override
  Future<void> close() async {
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

      emit(
        state.copyWith(transactions: transactions, isSyncing: false, err: null),
      );
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(err: e));
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
