part of 'wallet_bloc.dart';

enum WalletStatus { initial, loading, success, failure }

enum WalletTabs { wallets, exchange }

@freezed
sealed class WalletState with _$WalletState {
  const factory WalletState({
    @Default(WalletStatus.initial) WalletStatus status,
    @Default([]) List<Wallet> wallets,
    @Default([]) List<WalletWarning> warnings,
    @Default(false) bool isSyncing,
    @Default(null) Object? error,
  }) = _WalletState;
  const WalletState._();

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
