abstract interface class WalletVisibilityPort {
  Future<void> setHidden({required String walletId, required bool isHidden});
}
