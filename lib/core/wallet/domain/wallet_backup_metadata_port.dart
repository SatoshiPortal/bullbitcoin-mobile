abstract interface class WalletBackupMetadataPort {
  Future<void> recordEncryptedBackupCreated({
    required String walletId,
    required DateTime time,
  });
}
