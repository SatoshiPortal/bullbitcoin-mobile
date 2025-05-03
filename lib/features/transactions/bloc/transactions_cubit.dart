import 'dart:async';
import 'dart:collection';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_any_wallet_syncing_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_transactions_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transactions_cubit.freezed.dart';
part 'transactions_state.dart';

class TransactionsCubit extends Cubit<TransactionsState> {
  TransactionsCubit({
    required GetWalletTransactionsUsecase getWalletTransactionsUsecase,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
    required CheckAnyWalletSyncingUsecase checkAnyWalletSyncingUsecase,
  }) : _getWalletTransactionsUsecase = getWalletTransactionsUsecase,
       _watchStartedWalletSyncsUsecase = watchStartedWalletSyncsUsecase,
       _watchFinishedWalletSyncsUsecase = watchFinishedWalletSyncsUsecase,
       _checkAnyWalletSyncingUsecase = checkAnyWalletSyncingUsecase,
       super(const TransactionsState()) {
    _startedSyncsSubscription = _watchStartedWalletSyncsUsecase
        .execute()
        .listen((_) => emit(state.copyWith(isSyncing: true)));
    _finishedSyncsSubscription = _watchFinishedWalletSyncsUsecase
        .execute()
        .listen((_) => loadTxs());
  }

  final GetWalletTransactionsUsecase _getWalletTransactionsUsecase;
  final WatchStartedWalletSyncsUsecase _watchStartedWalletSyncsUsecase;
  final WatchFinishedWalletSyncsUsecase _watchFinishedWalletSyncsUsecase;
  final CheckAnyWalletSyncingUsecase _checkAnyWalletSyncingUsecase;

  StreamSubscription? _startedSyncsSubscription;
  StreamSubscription? _finishedSyncsSubscription;

  @override
  Future<void> close() async {
    await Future.wait([
      _startedSyncsSubscription?.cancel() ?? Future.value(),
      _finishedSyncsSubscription?.cancel() ?? Future.value(),
    ]);
    return super.close();
  }

  Future<void> loadTxs() async {
    try {
      final transactions = await _getWalletTransactionsUsecase.execute();
      final isSyncing = _checkAnyWalletSyncingUsecase.execute();

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
