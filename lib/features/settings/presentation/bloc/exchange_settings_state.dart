part of 'exchange_settings_cubit.dart';

enum ExchangeSettingsStatus { initial, loading, success, error }

@freezed
sealed class ExchangeSettingsState with _$ExchangeSettingsState {
  const factory ExchangeSettingsState({
    @Default(ExchangeSettingsStatus.initial) ExchangeSettingsStatus status,
    String? error,
    UserSummary? userSummary,
  }) = _ExchangeSettingsState;
}
