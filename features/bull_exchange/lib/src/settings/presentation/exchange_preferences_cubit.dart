import '../domain/usecases/get_exchange_preferences_usecase.dart';
import '../domain/usecases/update_exchange_preferences_usecase.dart';
import 'exchange_preferences_state.dart';

import '../domain/entities/exchange_preferences.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class ExchangePreferencesCubit extends Cubit<ExchangePreferencesState> {
  final GetExchangePreferencesUsecase _getExchangePreferencesUsecase;
  final UpdateExchangePreferencesUsecase _updateExchangePreferencesUsecase;

  ExchangePreferencesCubit({
    required this._getExchangePreferencesUsecase,
    required this._updateExchangePreferencesUsecase,
  }) : super(const ExchangePreferencesState());

  /// The preferences as the account last had them.
  ExchangePreferences? _loaded;

  Future<void> loadPreferences() async {
    emit(state.copyWith(isLoading: true, loadFailure: null));

    final result = await _getExchangePreferencesUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(
        isLoading: false,
        preferences: _loaded = value,
      ),
      Err(:final failure) => state.copyWith(
        isLoading: false,
        loadFailure: failure,
      ),
    });
  }

  void updateLanguage(String language) {
    final preferences = state.preferences;
    if (preferences == null) return;
    emit(state.copyWith(preferences: preferences.copyWith(language: language)));
  }

  void updateCurrency(String currency) {
    final preferences = state.preferences;
    if (preferences == null) return;
    emit(state.copyWith(preferences: preferences.copyWith(currency: currency)));
  }

  void updateEmailNotifications(bool enabled) {
    final preferences = state.preferences;
    if (preferences == null) return;
    emit(
      state.copyWith(
        preferences: preferences.copyWith(emailNotificationsEnabled: enabled),
      ),
    );
  }

  Future<void> savePreferences() async {
    final preferences = state.preferences;
    final loaded = _loaded;
    if (preferences == null || loaded == null || !preferences.isComplete) {
      return;
    }

    emit(state.copyWith(isSaving: true, saveFailure: null));

    final result = await _updateExchangePreferencesUsecase.execute(
      loaded: loaded,
      edited: preferences,
    );
    if (isClosed) return;

    if (result is Ok) _loaded = preferences;
    emit(switch (result) {
      Ok() => state.copyWith(isSaving: false),
      Err(:final failure) => state.copyWith(
        isSaving: false,
        saveFailure: failure,
      ),
    });
  }
}
