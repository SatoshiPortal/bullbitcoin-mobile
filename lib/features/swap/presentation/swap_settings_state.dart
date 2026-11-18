part of 'swap_settings_cubit.dart';

@freezed
abstract class SwapSettingsState with _$SwapSettingsState {
  const factory SwapSettingsState({
    @Default(false) bool loaded,
    @Default(false) bool exchangeFallbackEnabled,
    @Default(SwapRouteOverride.auto) SwapRouteOverride routeOverride,
    @Default(false) bool devModeEnabled,
    @Default(SwapServer.mainnetDefault) SwapServer swapServer,
    NetworkEnv? swapServerEnvironment,
    @Default(false) bool saving,
    SwapFailure? failure,
  }) = _SwapSettingsState;
  const SwapSettingsState._();

  bool get canEditSwapServer =>
      loaded &&
      (swapServerEnvironment == NetworkEnv.mainnet ||
          swapServerEnvironment == NetworkEnv.testnet);

  bool get isDefaultSwapServer => switch (swapServerEnvironment) {
    NetworkEnv.mainnet => swapServer == SwapServer.mainnetDefault,
    NetworkEnv.testnet => swapServer == SwapServer.testnetDefault,
    _ => false,
  };
}
