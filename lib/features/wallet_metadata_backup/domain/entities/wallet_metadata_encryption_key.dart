final class WalletMetadataEncryptionKey {
  static final _keyPattern = RegExp(r'^[0-9a-f]{64}$');

  final String hex;

  WalletMetadataEncryptionKey(String value) : hex = value.trim().toLowerCase() {
    if (!_keyPattern.hasMatch(hex)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a lowercase 32-byte hex key',
      );
    }
  }

  @override
  String toString() => 'WalletMetadataEncryptionKey(redacted)';
}
