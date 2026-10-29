import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import '../../domain/transaction_failure.dart';
import '../../domain/usecases/retry_unrelayed_transaction_usecase.dart';
import '../../domain/usecases/cancel_unrelayed_transaction_usecase.dart';

sealed class CbfRecoveryState {
  const CbfRecoveryState();
  bool get isBusy => this is CbfRecoveryRunning;
  TransactionFailure? get failure => switch (this) {
    CbfRecoveryFailed(:final reason) => reason,
    _ => null,
  };
}

final class CbfRecoveryReady extends CbfRecoveryState {
  const CbfRecoveryReady();
}

final class CbfRecoveryRunning extends CbfRecoveryState {
  const CbfRecoveryRunning();
}

final class CbfRecoveryFailed extends CbfRecoveryState {
  final TransactionFailure reason;
  const CbfRecoveryFailed(this.reason);
}

final class CbfRecoveryCubit extends Cubit<CbfRecoveryState> {
  final RetryUnrelayedTransactionUsecase _retry;
  final CancelUnrelayedTransactionUsecase _cancel;

  CbfRecoveryCubit(this._retry, this._cancel) : super(const CbfRecoveryReady());

  Future<bool> retry(String walletId, String txid) =>
      _run(() => _retry.execute(walletId, txid));
  Future<bool> cancel(String walletId, String txid) =>
      _run(() => _cancel.execute(walletId, txid));

  Future<bool> _run(
    Future<Result<void, TransactionFailure>> Function() action,
  ) async {
    if (state.isBusy || isClosed) {
      return false;
    }
    emit(const CbfRecoveryRunning());
    final result = await action();
    if (isClosed) {
      return false;
    }
    switch (result) {
      case Ok():
        emit(const CbfRecoveryReady());
        return true;
      case Err(:final failure):
        emit(CbfRecoveryFailed(failure));
        return false;
    }
  }
}
