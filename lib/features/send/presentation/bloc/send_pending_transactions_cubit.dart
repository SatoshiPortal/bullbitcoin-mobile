import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/usecases/delete_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

final class SendPendingTransactionsState {
  final List<PendingBitcoinTransaction> transactions;
  final int invalidCount;
  final SendFailure? failure;

  const SendPendingTransactionsState({
    this.transactions = const [],
    this.invalidCount = 0,
    this.failure,
  });
}

class SendPendingTransactionsCubit extends Cubit<SendPendingTransactionsState> {
  final WatchPendingBitcoinTransactionsUsecase
  _watchPendingBitcoinTransactionsUsecase;
  final DeletePendingBitcoinTransactionUsecase
  _deletePendingBitcoinTransactionUsecase;
  StreamSubscription<Result<PendingBitcoinTransactionSnapshot, SendFailure>>?
  _subscription;
  String? _walletId;

  SendPendingTransactionsCubit(
    this._watchPendingBitcoinTransactionsUsecase,
    this._deletePendingBitcoinTransactionUsecase,
  ) : super(const SendPendingTransactionsState());

  void watch(String walletId) {
    _walletId = walletId;
    _subscription?.cancel();
    _subscription = _watchPendingBitcoinTransactionsUsecase
        .execute(walletId)
        .listen((result) {
          switch (result) {
            case Ok(:final value):
              emit(
                SendPendingTransactionsState(
                  transactions: value.transactions,
                  invalidCount: value.invalidCount,
                ),
              );
            case Err(:final failure):
              emit(
                SendPendingTransactionsState(
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
    switch (await _deletePendingBitcoinTransactionUsecase.execute(
      transaction.id,
      expectedRevision: transaction.revision,
    )) {
      case Ok():
        return true;
      case Err(:final failure):
        emit(
          SendPendingTransactionsState(
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
