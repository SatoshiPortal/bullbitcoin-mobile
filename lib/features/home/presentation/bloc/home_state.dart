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
      : wallets
          .where(
            (wallet) => wallet.isDefault && wallet.network.isLiquid,
          )
          .firstOrNull;
  Wallet? get defaultBitcoinWallet => wallets.isEmpty
      ? null
      : wallets
          .where(
            (wallet) => wallet.isDefault && wallet.network.isBitcoin,
          )
          .firstOrNull;

  List<Wallet> get nonDefaultWallets =>
      wallets.where((wallet) => !wallet.isDefault).toList();
}
