import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_settings_failure.dart';

import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
import '../domain/exchange_preferences_machine.dart';

/// Shell of [transitionPreferences]. The save runs through the write gate
/// ([FinancialWriteKind.preferenceWrite]) of the session the screen opened
/// for.
class ExchangePreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  ExchangePreferencesBloc({
    required GetExchangePreferencesUsecase getExchangePreferencesUsecase,
    required UpdateExchangePreferencesUsecase updateExchangePreferencesUsecase,
    required ExchangeWriteGate writeGate,
    required ExchangeSession? session,
  }) : this._(
         preferencesStart(signedIn: session != null),
         getExchangePreferencesUsecase,
         updateExchangePreferencesUsecase,
         writeGate,
         session,
       );

  ExchangePreferencesBloc._(
    PreferencesNext start,
    this._get,
    this._update,
    this._gate,
    this._session,
  ) : super(start.state) {
    on<PreferencesEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final GetExchangePreferencesUsecase _get;
  final UpdateExchangePreferencesUsecase _update;
  final ExchangeWriteGate _gate;
  final ExchangeSession? _session;

  void _onEvent(PreferencesEvent event, Emitter<PreferencesState> emit) {
    final next = transitionPreferences(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<PreferencesEffect> effects) {
    for (final effect in effects) {
      unawaited(
        _answer(effect).then((event) {
          if (!isClosed) add(event);
        }),
      );
    }
  }

  Future<PreferencesEvent> _answer(PreferencesEffect effect) async =>
      switch (effect) {
        FetchPreferences(:final attempt) => PreferencesLoaded(
          attempt,
          await _get.execute(),
        ),
        SavePreferences(:final saved, :final edited) => PreferencesSaveAnswered(
          switch (_session) {
            null => const GateAdmitted(
              Err(ExchangeSettingsNotAuthenticatedFailure()),
            ),
            final session => await _gate.run(
              session,
              FinancialWriteKind.preferenceWrite,
              () => _update.execute(loaded: saved, edited: edited),
            ),
          },
        ),
      };
}
