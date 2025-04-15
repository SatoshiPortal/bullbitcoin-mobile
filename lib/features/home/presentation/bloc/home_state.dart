part of 'home_bloc.dart';

enum HomeStatus { initial, success, failure }

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState({
    @Default(HomeStatus.initial) HomeStatus status,
    @Default([]) List<Wallet> wallets,
    @Default(false) bool isSyncing,
    @Default(null) Object? error,
  }) = _HomeState;
  const HomeState._();

  Wallet? defaultLiquidWallet() => wallets.isEmpty
      ? null
      : wallets
          .where(
            (wallet) => wallet.isDefault && wallet.network.isLiquid,
          )
          .firstOrNull;
  Wallet? defaultBitcoinWallet() => wallets.isEmpty
      ? null
      : wallets
          .where(
            (wallet) => wallet.isDefault && wallet.network.isBitcoin,
          )
          .firstOrNull;

  List<Wallet> nonDefaultWallets() =>
      wallets.where((wallet) => !wallet.isDefault).toList();

  int totalBalance() => wallets.fold<int>(
        0,
        (previousValue, element) => previousValue + element.balanceSat.toInt(),
      );

  bool showBackupWarning() {
    final defaultWallets = wallets.where((wallet) => wallet.isDefault);
    return defaultWallets.isNotEmpty &&
        defaultWallets.any(
          (wallet) =>
              !wallet.isEncryptedVaultTested &&
              !wallet.isPhysicalBackupTested &&
              wallet.balanceSat > BigInt.from(0),
        );
  }
}
