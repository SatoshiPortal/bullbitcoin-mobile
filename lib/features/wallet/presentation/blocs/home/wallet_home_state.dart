part of 'wallet_home_bloc.dart';

enum WalletHomeStatus { initial, loading, success, failure }

enum WalletHomeTabs { wallets, exchange }

@freezed
sealed class WalletHomeState with _$WalletHomeState {
  const factory WalletHomeState({
    @Default(WalletHomeStatus.initial) WalletHomeStatus status,
    @Default([]) List<Wallet> wallets,
    @Default([]) List<WalletWarning> warnings,
    @Default(false) bool isSyncing,
    @Default(null) Object? error,
    UserSummaryModel? userSummary,
  }) = _WalletHomeState;
  const WalletHomeState._();

  Wallet? defaultLiquidWallet() =>
      wallets.isEmpty
          ? null
          : wallets
              .where((wallet) => wallet.isDefault && wallet.network.isLiquid)
              .firstOrNull;
  Wallet? defaultBitcoinWallet() =>
      wallets.isEmpty
          ? null
          : wallets
              .where((wallet) => wallet.isDefault && wallet.network.isBitcoin)
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
