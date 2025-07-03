part of 'wallet_settings_cubit.dart';

enum WalletDeleteStatus { initial, loading, success, error }

@freezed
sealed class WalletSettingsState with _$WalletSettingsState {
  const factory WalletSettingsState({
    @Default(WalletDeleteStatus.initial) WalletDeleteStatus deleteStatus,
    String? deleteError,
  }) = _WalletSettingsState;
}
