import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:secrets/src/domain/secrets_error.dart';

/// The symmetric key that encrypts/decrypts an [EncryptedVault].
///
/// Unlike the mnemonic, the backup key is MEANT to leave the package — the user
/// stores it (e.g. on the key server) to recover their vault — so [bytes] is
/// deliberately accessible and CANNOT be sealed without breaking that flow. The
/// package's guarantee is only that it never hands out the key and the
/// ciphertext from the SAME call (`encryptVault` takes the key as an input and
/// returns ciphertext only). The two-location discipline — store the key and
/// the ciphertext apart — is therefore a CALLER responsibility, not type-
/// enforced: a caller that derives a key ([Secret.bip85RecoverbullKey]) and then
/// keeps it beside the ciphertext has recreated the single-holder risk. Still
/// sensitive: `toString` never prints it. Must be >= 32 bytes.
@immutable
class VaultKey {
  factory VaultKey(Uint8List bytes) {
    if (bytes.length < 32) {
      throw InvalidVaultKeyError(
          'VaultKey must be >= 32 bytes', 'bytes.length');
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
      throw InvalidEncryptedVaultError('must not be empty', 'ciphertextJson');
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
