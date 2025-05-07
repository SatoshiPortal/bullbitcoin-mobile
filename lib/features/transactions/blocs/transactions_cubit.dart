import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transactions_cubit.freezed.dart';
part 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    String? walletId,
    required GetWalletTransactionsUsecase getWalletTransactionsUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required CheckWalletSyncingUsecase checkWalletSyncingUsecase,
  }) : _walletId = walletId,
       _getWalletTransactionsUsecase = getWalletTransactionsUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _checkWalletSyncingUsecase = checkWalletSyncingUsecase,
       super(const TransactionsState()) {
    _startedSyncSubscription = _watchStartedWalletSyncsUsecase
        .execute(walletId: _walletId)
        .listen((_) => emit(state.copyWith(isSyncing: true)));
    _finishedSyncSubscription = _watchFinishedWalletSyncsUsecase
        .execute(walletId: _walletId)
        .listen((_) => loadTxs());
  }

  final String? _walletId;
  final GetWalletTransactionsUsecase _getWalletTransactionsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final CheckWalletSyncingUsecase _checkWalletSyncingUsecase;

  StreamSubscription? _startedSyncSubscription;
  StreamSubscription? _finishedSyncSubscription;

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
      emit(state.copyWith(isSyncing: true));
      final transactions = await _getWalletTransactionsUsecase.execute(
        walletId: _walletId,
      );
      final isSyncing = _checkWalletSyncingUsecase.execute(walletId: _walletId);

      emit(
        state.copyWith(
          transactions: transactions,
          isSyncing: isSyncing,
          err: null,
        ),
      );
    } catch (e) {
      if (e is GetWalletTransactionsException) {
        emit(state.copyWith(err: e.message));
      } else if (!isClosed) {
        emit(state.copyWith(err: e));
      }
    }
  }

  void setFilter(TransactionsFilter filter) {
    emit(state.copyWith(filter: filter));
  }
}
