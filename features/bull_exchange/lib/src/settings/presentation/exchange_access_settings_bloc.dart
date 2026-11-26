import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/manage_exchange_access_usecase.dart';
import 'exchange_access_settings_machine.dart';

/// Shell of [transitionAccessSettings]: applies events in order and runs
/// the attempt of the [AccessSettingsWorking] state it enters.
class ExchangeAccessSettingsBloc
    extends Bloc<ExchangeAccessSettingsEvent, ExchangeAccessSettingsState> {
  ExchangeAccessSettingsBloc(this._watch, this._set)
    : super(AccessSettingsIdle(_watch.current)) {
    on<ExchangeAccessSettingsEvent>(_onEvent, transformer: sequential());
    _subscription = _watch.execute().listen((access) {
      if (!isClosed) add(AccessSettingsAccessChanged(access));
    });
  }

  final WatchExchangeAccessUsecase _watch;
  final ManageExchangeAccessUsecase _set;
  StreamSubscription<ExchangeAccess>? _subscription;

  void _onEvent(
    ExchangeAccessSettingsEvent event,
    Emitter<ExchangeAccessSettingsState> emit,
  ) {
    final previous = state;
    final next = transitionAccessSettings(previous, event);
    if (next == previous) return;
    emit(next);
    if (previous is! AccessSettingsWorking && next is AccessSettingsWorking) {
      unawaited(_run(next.attempt));
    }
  }

  Future<void> _run(ExchangeAccessAttempt attempt) async {
    final result = await switch (attempt) {
      ExchangeAccessAttempt.enable => _set.execute(true),
      ExchangeAccessAttempt.signOut => _set.execute(false),
      ExchangeAccessAttempt.retry => _set.retry(),
    };
    if (isClosed) return;
    add(switch (result) {
      Ok() => AccessSettingsAttemptSucceeded(_watch.current),
      Err(:final failure) => AccessSettingsAttemptFailed(failure),
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
