part of 'wallet_bloc.dart';

enum WalletStatus { initial, loading, success, failure }

@freezed
sealed class WalletState with _$WalletState {
  const factory WalletState({
    @Default(WalletStatus.initial) WalletStatus status,
    @Default([]) List<Wallet> wallets,
    @Default([]) List<WalletWarning> warnings,
    @Default({}) Map<String, bool> syncStatus,
    WalletFailure? failure,
    @Default(0) int unconfirmedIncomingBalance,
    @Default(false) bool isRefreshing,
    @Default(false) bool isDeletingWallet,
    WalletFailure? walletDeletionFailure,
    @Default(false) bool isCheckingServiceStatus,
    @Default(false) bool backupWarningDismissed,
    @Default(false) bool isOnLegacyStorage,
    @Default(false) bool legacyStorageWarningDismissed,
  }) = _WalletState;
  const WalletState._();

  bool get isSyncing => syncStatus.values.any((syncing) => syncing);

  Wallet? defaultLiquidWallet() => wallets.isEmpty
      ? null
      : wallets
            .where((wallet) => wallet.isDefault && wallet.network.isLiquid)
            .firstOrNull;
  Wallet? defaultBitcoinWallet() => wallets.isEmpty
      ? null
      : wallets
            .where((wallet) => wallet.isDefault && wallet.network.isBitcoin)
            .firstOrNull;

  bool get noWalletsFound => failure is NoWalletsFoundFailure;

  WalletFailure? get loadFailure =>
      failure is NoWalletsFoundFailure ? null : failure;

  int totalBalance() => wallets.fold<int>(
    0,
    (previousValue, element) => previousValue + element.balanceSat.toInt(),
  );

  bool hasNoBackup() {
    final defaultWallets = wallets.where((wallet) => wallet.isDefault);
    return defaultWallets.isNotEmpty &&
        defaultWallets.any(
          (wallet) =>
              !wallet.isEncryptedVaultTested && !wallet.isPhysicalBackupTested,
        );
  }

  bool showBackupWarning() {
    return hasNoBackup() && totalBalance() > 0 && !backupWarningDismissed;
  }

  bool showLegacyStorageWarning() {
    return isOnLegacyStorage && !legacyStorageWarningDismissed;
  }
}
