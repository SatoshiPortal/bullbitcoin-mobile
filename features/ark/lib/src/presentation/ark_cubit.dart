import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/usecases/read_ark_usecase.dart';

sealed class ArkViewState {
  const ArkViewState();
}

final class ArkLoading extends ArkViewState {
  const ArkLoading();
}

final class ArkObserved extends ArkViewState {
  final ArkSnapshot snapshot;
  const ArkObserved(this.snapshot);
}

final class ArkViewFailed extends ArkViewState {
  final ArkFailure failure;
  final ArkSnapshot? lastObserved;
  const ArkViewFailed(this.failure, {this.lastObserved});
}

final class ArkCubit extends Cubit<ArkViewState> {
  final ReadArkUsecase _read;
  final SynchronizeArkUsecase _synchronize;
  final ArkAccountId account;
  bool _refreshing = false;
  bool _again = false, _againRenews = false;
  bool _reading = false;
  int _epoch = 0;
  ArkCubit(this._read, this._synchronize, {required this.account})
    : super(const ArkLoading());

  Future<void> load() async {
    if (isClosed || _reading || _refreshing) return;
    _reading = true;
    final epoch = ++_epoch;
    try {
      final result = await _read.execute(account);
      if (epoch == _epoch) _publish(result);
    } finally {
      _reading = false;
    }
  }

  Future<void> refresh({bool renew = false}) async {
    if (isClosed) return;
    if (_refreshing) {
      // A refresh already under way may have read the account before the
      // change this caller expects; run once more after it.
      _again = true;
      _againRenews = _againRenews || renew;
      return;
    }
    _refreshing = true;
    final epoch = ++_epoch;
    try {
      final result = (await _synchronize.execute(
        account,
        renew: renew,
      )).map((value) => value.snapshot);
      if (epoch == _epoch) _publish(result);
    } finally {
      _refreshing = false;
    }
    if (_again && !isClosed) {
      final renews = _againRenews;
      _again = false;
      _againRenews = false;
      await refresh(renew: renews);
    }
  }

  void _publish(Result<ArkSnapshot, ArkFailure> result) {
    if (isClosed) return;
    final previous = switch (state) {
      ArkObserved(:final snapshot) => snapshot,
      ArkViewFailed(:final lastObserved) => lastObserved,
      _ => null,
    };
    switch (result) {
      case Ok(:final value):
        emit(ArkObserved(value));
      case Err(:final failure):
        emit(ArkViewFailed(failure, lastObserved: previous));
    }
  }
}
