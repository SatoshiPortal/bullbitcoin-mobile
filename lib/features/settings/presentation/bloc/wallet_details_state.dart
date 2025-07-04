part of 'wallet_details_cubit.dart';

enum WalletDeleteStatus { initial, loading, success, error }

@freezed
sealed class WalletDetailsState with _$WalletDetailsState {
  const factory WalletDetailsState({
    @Default(WalletDeleteStatus.initial) WalletDeleteStatus deleteStatus,
    String? deleteError,
  }) = _WalletDetailsState;
}
