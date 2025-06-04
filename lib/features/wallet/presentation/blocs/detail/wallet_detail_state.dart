part of 'wallet_detail_bloc.dart';

@freezed
sealed class WalletDetailState with _$WalletDetailState {
  const factory WalletDetailState({Wallet? wallet, Object? error}) =
      _WalletDetailState;

  const WalletDetailState._();
}
