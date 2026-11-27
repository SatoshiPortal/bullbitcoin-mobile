import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_access_settings_state.dart';
import '../domain/exchange_access_settings_event.dart';
import '../domain/usecases/enable_exchange_access_usecase.dart';
import '../domain/usecases/get_exchange_access_usecase.dart';
import '../domain/usecases/resolve_exchange_access_usecase.dart';
import '../domain/usecases/sign_out_of_exchange_usecase.dart';
import '../domain/usecases/watch_exchange_access_usecase.dart';

/// Shell of [ExchangeAccessSettingsState.next]: applies events in order and runs
/// the attempt of the [AccessSettingsWorking] state it enters.
class ExchangeAccessSettingsBloc
    extends Bloc<ExchangeAccessSettingsEvent, ExchangeAccessSettingsState> {
  ExchangeAccessSettingsBloc({
    required this._getAccess,
    required WatchExchangeAccessUsecase watchAccess,
    required this._enableAccess,
    required this._signOut,
    required this._resolveAccess,
  }) : super(AccessSettingsIdle(_getAccess.execute())) {
    on<ExchangeAccessSettingsEvent>(_onEvent, transformer: sequential());
    _subscription = watchAccess.execute().listen((access) {
      if (!isClosed) add(AccessSettingsAccessChanged(access));
    });
  }

  final GetExchangeAccessUsecase _getAccess;
  final EnableExchangeAccessUsecase _enableAccess;
  final SignOutOfExchangeUsecase _signOut;
  final ResolveExchangeAccessUsecase _resolveAccess;
  StreamSubscription<ExchangeAccess>? _subscription;

  void _onEvent(
    ExchangeAccessSettingsEvent event,
    Emitter<ExchangeAccessSettingsState> emit,
  ) {
    final previous = state;
    final next = previous.next(event);
    if (next == previous) return;
    emit(next);
    if (previous is! AccessSettingsWorking && next is AccessSettingsWorking) {
      unawaited(_run(next.attempt));
    }
  }

  Future<void> _run(ExchangeAccessAttempt attempt) async {
    final result = await switch (attempt) {
      ExchangeAccessAttempt.enable => _enableAccess.execute(),
      ExchangeAccessAttempt.signOut => _signOut.execute(),
      ExchangeAccessAttempt.retry => _resolveAccess.execute(),
    };
    if (isClosed) return;
    add(switch (result) {
      Ok() => AccessSettingsAttemptSucceeded(_getAccess.execute()),
      Err(:final failure) => AccessSettingsAttemptFailed(failure),
    });
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
