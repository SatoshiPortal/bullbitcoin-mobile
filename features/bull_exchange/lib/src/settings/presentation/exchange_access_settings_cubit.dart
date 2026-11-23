import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/manage_exchange_access_usecase.dart';

class ExchangeAccessSettingsState {
  const ExchangeAccessSettingsState(
    this.access, {
    this.busy = false,
    this.failure,
  });
  final ExchangeAccess access;
  final bool busy;
  final ExchangeFailure? failure;
}

class ExchangeAccessSettingsCubit extends Cubit<ExchangeAccessSettingsState> {
  ExchangeAccessSettingsCubit(this._watch, this._set)
    : super(ExchangeAccessSettingsState(_watch.current)) {
    _subscription = _watch.execute().listen((access) {
      if (!isClosed) {
        emit(
          ExchangeAccessSettingsState(
            access,
            busy: state.busy,
            failure: state.failure,
          ),
        );
      }
    });
  }
  final WatchExchangeAccessUsecase _watch;
  final ManageExchangeAccessUsecase _set;
  StreamSubscription<ExchangeAccess>? _subscription;

  Future<bool> setEnabled(bool enabled) async {
    if (state.busy ||
        (enabled && state.access is ExchangeAccessSignOutIncomplete)) {
      return false;
    }
    emit(ExchangeAccessSettingsState(state.access, busy: true));
    final result = await _set.execute(enabled);
    if (isClosed) return false;
    switch (result) {
      case Err(:final failure):
        emit(ExchangeAccessSettingsState(state.access, failure: failure));
        return false;
      case Ok():
        emit(ExchangeAccessSettingsState(_watch.current));
        return true;
    }
  }

  Future<void> retry() async {
    if (state.busy) return;
    emit(ExchangeAccessSettingsState(state.access, busy: true));
    final result = await _set.retry();
    if (isClosed) return;
    emit(
      ExchangeAccessSettingsState(
        state.access,
        failure: switch (result) {
          Err(:final failure) => failure,
          Ok() => null,
        },
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
