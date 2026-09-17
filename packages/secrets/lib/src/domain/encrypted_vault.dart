/// A sealed vault: the ciphertext, and the key that opens it.
///
/// The two travel together out of `backup.vault` and must not be stored
/// together — hold both and you hold the mnemonic. [derivationPath] is
/// also written inside [file], so a restore needs only the file and the
/// key.
final class EncryptedVault {
  final String file;

  final String key;

  final String derivationPath;

  const EncryptedVault({
    required this.file,
    required this.key,
    required this.derivationPath,
  });

  @override
  String toString() => 'EncryptedVault($derivationPath, •••)';
}
