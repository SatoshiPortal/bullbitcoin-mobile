import 'package:bb_mobile/features/exchange_settings/domain/usecases/get_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/usecases/update_exchange_preferences_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/presentation/exchange_preferences_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

class ExchangePreferencesCubit extends Cubit<ExchangePreferencesState> {
  final GetExchangePreferencesUsecase _getExchangePreferencesUsecase;
  final UpdateExchangePreferencesUsecase _updateExchangePreferencesUsecase;

  ExchangePreferencesCubit({
    required this._getExchangePreferencesUsecase,
    required this._updateExchangePreferencesUsecase,
  }) : super(const ExchangePreferencesState());

  Future<void> loadPreferences() async {
    emit(state.copyWith(isLoading: true, loadFailure: null));

    final result = await _getExchangePreferencesUsecase.execute();
    if (isClosed) return;

    emit(switch (result) {
      Ok(:final value) => state.copyWith(isLoading: false, preferences: value),
      Err(:final failure) => state.copyWith(
        isLoading: false,
        loadFailure: failure,
      ),
    });
  }

  void updateLanguage(String? language) {
    final preferences = state.preferences;
    if (preferences == null) return;
    emit(state.copyWith(preferences: preferences.copyWith(language: language)));
  }

  void updateCurrency(String? currency) {
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
    if (preferences == null || !preferences.isComplete) return;

    emit(state.copyWith(isSaving: true, saveFailure: null));

    final result = await _updateExchangePreferencesUsecase.execute(preferences);
    if (isClosed) return;

    emit(switch (result) {
      Ok() => state.copyWith(isSaving: false),
      Err(:final failure) => state.copyWith(
        isSaving: false,
        saveFailure: failure,
      ),
    });
  }
}
