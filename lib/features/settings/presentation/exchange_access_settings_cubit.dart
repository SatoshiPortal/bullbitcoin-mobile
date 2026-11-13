import 'dart:async';

import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/manage_exchange_access_usecase.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeAccessSettingsState {
  const ExchangeAccessSettingsState(
    this.access, {
    this.busy = false,
    this.failure,
  });
  final ExchangeAccess access;
  final bool busy;
  final SettingsFailure? failure;
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
  final WatchSettingsExchangeAccessUsecase _watch;
  final SetSettingsExchangeAccessUsecase _set;
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
