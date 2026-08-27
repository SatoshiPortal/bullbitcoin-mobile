enum WalletPreferencesRestoreDisposition {
  applyToCreatedWallet,
  conflictWithExistingWallet,
  deferredMissingWallet,
}

abstract final class WalletPreferencesRestorePolicy {
  static WalletPreferencesRestoreDisposition classify({
    required bool walletExists,
    required bool createdInRecovery,
  }) {
    if (!walletExists) {
      return WalletPreferencesRestoreDisposition.deferredMissingWallet;
    }
    if (createdInRecovery) {
      return WalletPreferencesRestoreDisposition.applyToCreatedWallet;
    }
    return WalletPreferencesRestoreDisposition.conflictWithExistingWallet;
  }
}
