import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/delete_wallet_pending_transaction_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/watch_wallet_pending_transactions_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class WalletPendingTransactionsState {
  final List<PendingBitcoinTransaction> transactions;
  final int invalidCount;
  final WalletFailure? failure;

  const WalletPendingTransactionsState({
    this.transactions = const [],
    this.invalidCount = 0,
    this.failure,
  });
}

class WalletPendingTransactionsCubit
    extends Cubit<WalletPendingTransactionsState> {
  final WatchWalletPendingTransactionsUsecase
  _watchWalletPendingTransactionsUsecase;
  final DeleteWalletPendingTransactionUsecase
  _deleteWalletPendingTransactionUsecase;
  StreamSubscription<Result<PendingBitcoinTransactionSnapshot, WalletFailure>>?
  _subscription;
  String? _walletId;

  WalletPendingTransactionsCubit(
    this._watchWalletPendingTransactionsUsecase,
    this._deleteWalletPendingTransactionUsecase,
  ) : super(const WalletPendingTransactionsState());

  void watch(String walletId) {
    _walletId = walletId;
    _subscription?.cancel();
    _subscription = _watchWalletPendingTransactionsUsecase
        .execute(walletId)
        .listen((result) {
          switch (result) {
            case Ok(:final value):
              emit(
                WalletPendingTransactionsState(
                  transactions: value.transactions,
                  invalidCount: value.invalidCount,
                ),
              );
            case Err(:final failure):
              emit(
                WalletPendingTransactionsState(
                  transactions: state.transactions,
                  invalidCount: state.invalidCount,
                  failure: failure,
                ),
              );
          }
        });
  }

  void retry() {
    final walletId = _walletId;
    if (walletId != null) watch(walletId);
  }

  Future<bool> delete(PendingBitcoinTransaction transaction) async {
    switch (await _deleteWalletPendingTransactionUsecase.execute(transaction)) {
      case Ok():
        return true;
      case Err(:final failure):
        emit(
          WalletPendingTransactionsState(
            transactions: state.transactions,
            invalidCount: state.invalidCount,
            failure: failure,
          ),
        );
        return false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
