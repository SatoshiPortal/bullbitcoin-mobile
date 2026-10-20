import 'package:bb_mobile/features/exchange_settings/domain/entities/exchange_preferences.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_preferences_state.freezed.dart';

@freezed
abstract class ExchangePreferencesState with _$ExchangePreferencesState {
  const factory ExchangePreferencesState({
    ExchangePreferences? preferences,
    @Default(false) bool isLoading,
    @Default(false) bool isSaving,
    ExchangeSettingsFailure? loadFailure,
    ExchangeSettingsFailure? saveFailure,
  }) = _ExchangePreferencesState;
}
