import 'dart:typed_data';

import 'package:meta/meta.dart';

/// The symmetric key that encrypts/decrypts an [EncryptedVault].
///
/// Unlike the mnemonic, the backup key is MEANT to leave the package — the user
/// stores it to recover their vault — so [bytes] is accessible. It is still
/// sensitive: `toString` never prints it. Must be >= 32 bytes.
@immutable
class VaultKey {
  factory VaultKey(Uint8List bytes) {
    if (bytes.length < 32) {
      throw ArgumentError.value(
          bytes.length, 'bytes.length', 'VaultKey must be >= 32 bytes');
    }
    return VaultKey._(Uint8List.fromList(bytes));
  }
  const VaultKey._(this._bytes);

  final Uint8List _bytes;

  /// A defensive COPY — callers cannot mutate the key buffer in place (which
  /// would otherwise corrupt the vault key, breaking `@immutable`).
  Uint8List get bytes => Uint8List.fromList(_bytes);

  @override
  String toString() => 'VaultKey(${_bytes.length} bytes)';
}

/// An encrypted vault — the `recoverbull` `BullBackup` JSON. NON-secret
/// (ciphertext); safe to persist and transport.
@immutable
class EncryptedVault {
  factory EncryptedVault(String ciphertextJson) {
    if (ciphertextJson.isEmpty) {
      throw ArgumentError.value(
          ciphertextJson, 'ciphertextJson', 'must not be empty');
    }
    return EncryptedVault._(ciphertextJson);
  }
  const EncryptedVault._(this.ciphertextJson);

  final String ciphertextJson;

  @override
  bool operator ==(Object other) =>
      other is EncryptedVault && other.ciphertextJson == ciphertextJson;

  @override
  int get hashCode => ciphertextJson.hashCode;

  @override
  String toString() => 'EncryptedVault(${ciphertextJson.length} chars)';
}
