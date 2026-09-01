part of 'wallet_bloc.dart';

enum WalletStatus { initial, loading, success, failure }

@freezed
sealed class WalletState with _$WalletState {
  const factory WalletState({
    @Default(WalletStatus.initial) WalletStatus status,
    @Default([]) List<Wallet> wallets,
    NoWalletsFoundException? noWalletsFoundException,
    @Default([]) List<WalletWarning> warnings,
    @Default({}) Map<String, bool> syncStatus,
    @Default(null) Object? error,
    @Default(0) int unconfirmedIncomingBalance,
    @Default(false) bool isRefreshing,
    @Default(false) bool isDeletingWallet,
    WalletError? walletDeletionError,
    @Default(false) bool isCheckingServiceStatus,
    @Default(0) int spBalanceSat,
    @Default(false) bool isSpWalletSetup,
    // The SP feature gate (superuser + dev mode), mirrored here so the wallet
    // UI reads its own state instead of importing the settings feature.
    @Default(false) bool isSpFeatureEnabled,
    @Default(false) bool isSpWalletLoading,
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

  bool get noWalletsFound => noWalletsFoundException != null;

  /// The SP balance counts only while the SP card is shown, on the same
  /// condition the card itself uses. A wallet the user cannot see must not
  /// move the total.
  bool get showSpWallet => isSpFeatureEnabled && isSpWalletSetup;

  int totalBalance() =>
      wallets.fold<int>(
        0,
        (previousValue, element) => previousValue + element.balanceSat.toInt(),
      ) +
      (showSpWallet ? spBalanceSat : 0);

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
