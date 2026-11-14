/// A validated encrypted vault. Wire encoding belongs to the data layer.
class EncryptedVault {
  static const maxCiphertextBytes = 1024 * 1024;
  final String id;
  final String salt;
  final List<int> ciphertext;
  final DateTime createdAt;
  final String? derivationPath;

  EncryptedVault({
    required String id,
    required String salt,
    required List<int> ciphertext,
    required this.createdAt,
    this.derivationPath,
  }) : id = id.toLowerCase(),
       salt = salt.toLowerCase(),
       ciphertext = List.unmodifiable(ciphertext) {
    if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(id)) {
      throw ArgumentError('Invalid vault identifier');
    }
    if (!RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(salt)) {
      throw ArgumentError('Invalid vault salt');
    }
    if (ciphertext.length < 64 ||
        ciphertext.length > maxCiphertextBytes ||
        (ciphertext.length - 48) % 16 != 0 ||
        ciphertext.any((byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('Invalid encrypted data size');
    }
  }

  String get filename =>
      '${createdAt.toIso8601String().substring(0, 10)}_encrypted_vault.json';
}
