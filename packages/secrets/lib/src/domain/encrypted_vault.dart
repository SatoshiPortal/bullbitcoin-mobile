/// An opaque RecoverBull JSON document, without the recovery key.
final class EncryptedVault {
  final String json;

  /// Format and authentication are checked by the vault operation, which returns a typed failure for invalid input.
  const EncryptedVault({required this.json});

  @override
  String toString() => 'EncryptedVault(•••)';
}

/// The 32-byte recovery key. Store it separately from the vault it opens.
final class VaultKey {
  final String hex;

  factory VaultKey(String hex) {
    final normalized = hex.replaceAll(RegExp(r'\s'), '').toLowerCase();
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
      throw const FormatException(
        'a vault key must contain 32 hexadecimal bytes',
      );
    }
    return VaultKey._(normalized);
  }

  const VaultKey._(this.hex);

  @override
  String toString() => 'VaultKey(•••)';
}
