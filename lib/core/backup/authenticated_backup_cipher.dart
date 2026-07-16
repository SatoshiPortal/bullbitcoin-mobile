import 'dart:convert';
import 'dart:typed_data';

import 'package:hex/hex.dart';
import 'package:recoverbull/recoverbull.dart';

final class AuthenticatedBackupCipherException implements Exception {
  final String message;
  final Object? cause;

  const AuthenticatedBackupCipherException(this.message, {this.cause});

  @override
  String toString() => 'AuthenticatedBackupCipherException: $message';
}

final class AuthenticatedBackupCipherKey {
  static final _hex32Pattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final String _hex;

  AuthenticatedBackupCipherKey(String hex) : _hex = hex.trim().toLowerCase() {
    if (!_hex32Pattern.hasMatch(_hex)) {
      throw const AuthenticatedBackupCipherException(
        'encryption key must be a 32-byte hex value',
      );
    }
  }
}

final class AuthenticatedBackupCiphertext {
  static const int minimumByteLength = 64;
  static const int maximumByteLength = 2 * 1024 * 1024;

  final String value;
  final int byteLength;

  const AuthenticatedBackupCiphertext._(this.value, this.byteLength);

  factory AuthenticatedBackupCiphertext(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const AuthenticatedBackupCipherException('ciphertext is required');
    }
    if (trimmed != value) {
      throw const AuthenticatedBackupCipherException(
        'ciphertext must use canonical base64',
      );
    }

    final Uint8List bytes;
    try {
      bytes = base64.decode(trimmed);
    } on FormatException catch (error) {
      throw AuthenticatedBackupCipherException(
        'ciphertext must use canonical base64',
        cause: error,
      );
    }
    if (base64.encode(bytes) != trimmed) {
      throw const AuthenticatedBackupCipherException(
        'ciphertext must use canonical base64',
      );
    }
    if (bytes.length < minimumByteLength) {
      throw const AuthenticatedBackupCipherException('ciphertext is too short');
    }
    if (bytes.length > maximumByteLength) {
      throw const AuthenticatedBackupCipherException('ciphertext is too large');
    }
    return AuthenticatedBackupCiphertext._(trimmed, bytes.length);
  }
}

/// RecoverBull-compatible `base64(nonce16 || AES-CBC || HMAC-SHA256)` cipher.
final class RecoverBullAuthenticatedBackupCipher {
  const RecoverBullAuthenticatedBackupCipher();

  AuthenticatedBackupCiphertext encrypt({
    required String plaintext,
    required AuthenticatedBackupCipherKey key,
  }) {
    try {
      final backup = RecoverBull.createBackup(
        secret: utf8.encode(plaintext),
        backupKey: HEX.decode(key._hex),
      );
      return AuthenticatedBackupCiphertext(base64.encode(backup.ciphertext));
    } on Exception catch (error) {
      throw AuthenticatedBackupCipherException(
        'failed to encrypt content',
        cause: error,
      );
    }
  }

  String decrypt({
    required AuthenticatedBackupCiphertext ciphertext,
    required AuthenticatedBackupCipherKey key,
  }) {
    try {
      final plaintext = RecoverBull.restoreBackup(
        backup: BullBackup(
          createdAt: 0,
          id: const [],
          ciphertext: base64.decode(ciphertext.value),
          salt: const [],
        ),
        backupKey: HEX.decode(key._hex),
      );
      return utf8.decode(plaintext);
    } on Exception catch (error) {
      throw AuthenticatedBackupCipherException(
        'failed to decrypt content',
        cause: error,
      );
    }
  }
}
