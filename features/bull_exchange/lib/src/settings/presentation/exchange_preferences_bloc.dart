import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
import '../domain/exchange_preferences_machine.dart';

/// Shell of [transitionPreferences]. The save is answered for the session
/// the screen opened for.
class ExchangePreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  ExchangePreferencesBloc({
    required ExchangeSession? session,
    required GetExchangePreferencesUsecase getPreferences,
    required UpdateExchangePreferencesUsecase updatePreferences,
  }) : this._(
         preferencesStart(signedIn: session != null),
         session,
         getPreferences,
         updatePreferences,
       );

  ExchangePreferencesBloc._(
    PreferencesNext start,
    this._session,
    this._getPreferences,
    this._updatePreferences,
  ) : super(start.state) {
    on<PreferencesEvent>(_onEvent, transformer: sequential());
    _run(start.effects);
  }

  final ExchangeSession? _session;
  final GetExchangePreferencesUsecase _getPreferences;
  final UpdateExchangePreferencesUsecase _updatePreferences;

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
          await _getPreferences.execute(_session),
        ),
        SavePreferences(:final saved, :final edited) => PreferencesSaveAnswered(
          await _updatePreferences.execute(
            _session,
            loaded: saved,
            edited: edited,
          ),
        ),
      };
}
