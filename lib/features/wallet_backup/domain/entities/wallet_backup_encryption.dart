import 'dart:convert';

final class WalletBackupEncryptionKey {
  final String hex;

  WalletBackupEncryptionKey(String value) : hex = value.trim().toLowerCase() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw ArgumentError.value(
        value,
        'value',
        'Invalid backup encryption key',
      );
    }
  }
}

final class WalletBackupCiphertext {
  static const minimumByteLength = 64;
  static const maximumByteLength = 1024 * 1024;
  static const maximumEncodedLength = ((maximumByteLength + 2) ~/ 3) * 4;

  final String value;
  final int byteLength;

  WalletBackupCiphertext(String value)
    : value = value,
      byteLength =
          _measure(value) ??
          (throw ArgumentError.value(value, 'value', 'Invalid ciphertext'));

  WalletBackupCiphertext._(this.value, this.byteLength);

  static WalletBackupCiphertext? tryParse(String value) {
    final length = _measure(value);
    return length == null ? null : WalletBackupCiphertext._(value, length);
  }

  static int? _measure(String value) {
    if (value.isEmpty ||
        value.length > maximumEncodedLength ||
        value.trim() != value) {
      return null;
    }
    final List<int> bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      return null;
    }
    return base64.encode(bytes) == value &&
            bytes.length >= minimumByteLength &&
            bytes.length <= maximumByteLength
        ? bytes.length
        : null;
  }
}
