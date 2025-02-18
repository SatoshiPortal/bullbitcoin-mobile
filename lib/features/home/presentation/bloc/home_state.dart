part of 'home_bloc.dart';

enum HomeStatus { initial, success, failure }

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState({
    @Default(HomeStatus.initial) HomeStatus status,
    @Default([]) List<Wallet> wallets,
    //required List<Transaction> transactions,
    @Default(false) bool isSyncingTransactions,
    @Default(null) Object? error,
  }) = _HomeState;
  const HomeState._();

  Wallet? get defaultLiquidWallet => wallets.isEmpty
      ? null
      : wallets.firstWhere(
          (wallet) => wallet.network.isLiquid,
        );
  Wallet? get defaultBitcoinWallet => wallets.isEmpty
      ? null
      : wallets.firstWhere(
          (wallet) => wallet.network.isBitcoin,
        );
}
