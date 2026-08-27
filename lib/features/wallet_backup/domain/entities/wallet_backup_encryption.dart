import 'dart:convert';

final class WalletBackupEncryptionKey {
  final String hex;

  WalletBackupEncryptionKey(String value) : hex = value.trim().toLowerCase() {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hex)) {
      throw ArgumentError.value(
        value,
        'value',
        'wallet backup encryption key must be a 32-byte hex value',
      );
    }
  }
}

final class WalletBackupCiphertext {
  static const minimumByteLength = 64;
  static const maximumByteLength = 2 * 1024 * 1024;
  static const maximumEncodedLength = ((maximumByteLength + 2) ~/ 3) * 4;

  final String value;
  final int byteLength;

  WalletBackupCiphertext(String value)
    : value = value,
      byteLength = _validateAndMeasure(value);

  static int _validateAndMeasure(String value) {
    if (value.length > maximumEncodedLength) {
      throw ArgumentError.value(
        value.length,
        'value',
        'wallet backup ciphertext is too large',
      );
    }
    if (value.isEmpty || value.trim() != value) {
      throw ArgumentError.value(
        value,
        'value',
        'wallet backup ciphertext must use canonical base64',
      );
    }
    final List<int> bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      throw ArgumentError.value(
        value,
        'value',
        'wallet backup ciphertext must use canonical base64',
      );
    }
    if (base64.encode(bytes) != value) {
      throw ArgumentError.value(
        value,
        'value',
        'wallet backup ciphertext must use canonical base64',
      );
    }
    if (bytes.length < minimumByteLength) {
      throw ArgumentError.value(
        bytes.length,
        'value',
        'wallet backup ciphertext is too short',
      );
    }
    if (bytes.length > maximumByteLength) {
      throw ArgumentError.value(
        bytes.length,
        'value',
        'wallet backup ciphertext is too large',
      );
    }
    return bytes.length;
  }
}
