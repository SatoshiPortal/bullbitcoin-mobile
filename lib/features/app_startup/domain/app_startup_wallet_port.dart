abstract interface class AppStartupWalletPort {
  Future<bool> hasMainnetBitcoinEncryptedBackup();

  Future<bool> hasTestedRecoverBullBackup();
}
