part of 'swap_settings_cubit.dart';

@freezed
abstract class SwapSettingsState with _$SwapSettingsState {
  const factory SwapSettingsState({
    @Default(false) bool loaded,
    @Default(false) bool exchangeFallbackEnabled,
    @Default(SwapRouteOverride.auto) SwapRouteOverride routeOverride,
    @Default(false) bool devModeEnabled,
    @Default(false) bool saving,
    SwapFailure? failure,
  }) = _SwapSettingsState;
}
