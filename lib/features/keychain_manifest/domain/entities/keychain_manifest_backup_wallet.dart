final class KeychainManifestBackupWallet {
  final String xprvBase58;
  final String parentFingerprint;

  const KeychainManifestBackupWallet({
    required this.xprvBase58,
    required this.parentFingerprint,
  });
}

abstract interface class KeychainManifestBackupWalletPort {
  Future<KeychainManifestBackupWallet> deriveDefaultWallet();
}
