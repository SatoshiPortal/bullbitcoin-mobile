import 'dart:isolate';
import 'dart:typed_data';

import 'package:recoverbull/recoverbull.dart';

final class RecoverBullEncryptionException implements Exception {
  const RecoverBullEncryptionException();
}

/// Bounded, off-UI-thread access to the existing RecoverBull file encryptor.
/// Bytes are RecoverBull's IV || AES-CBC ciphertext || HMAC-SHA256.
final class RecoverBullEncryption {
  static const maxPlaintextBytes = 1024 * 1024;
  static const maxCiphertextBytes = maxPlaintextBytes + 64;

  const RecoverBullEncryption();

  Future<Uint8List> encrypt(Uint8List key, Uint8List plaintext) async {
    if (key.length != 32 ||
        plaintext.isEmpty ||
        plaintext.length > maxPlaintextBytes) {
      throw const RecoverBullEncryptionException();
    }
    final keyCopy = Uint8List.fromList(key);
    final input = Uint8List.fromList(plaintext);
    return Isolate.run(() => _encrypt(keyCopy, input));
  }

  Future<Uint8List> decrypt(Uint8List key, Uint8List ciphertext) async {
    if (key.length != 32 ||
        ciphertext.length < 64 ||
        ciphertext.length > maxCiphertextBytes ||
        (ciphertext.length - 48) % 16 != 0) {
      throw const RecoverBullEncryptionException();
    }
    final keyCopy = Uint8List.fromList(key);
    final input = Uint8List.fromList(ciphertext);
    return Isolate.run(() => _decrypt(keyCopy, input));
  }

  static Uint8List _encrypt(Uint8List key, Uint8List input) {
    try {
      return Uint8List.fromList(
        RecoverBull.createBackup(secret: input, backupKey: key).ciphertext,
      );
    } on Exception {
      throw const RecoverBullEncryptionException();
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  static Uint8List _decrypt(Uint8List key, Uint8List input) {
    try {
      final plaintext = RecoverBull.restoreBackup(
        backup: BullBackup(
          createdAt: 0,
          id: const [],
          salt: const [],
          ciphertext: input,
        ),
        backupKey: key,
      );
      if (plaintext.length > maxPlaintextBytes) {
        throw const RecoverBullEncryptionException();
      }
      return Uint8List.fromList(plaintext);
    } on Exception {
      throw const RecoverBullEncryptionException();
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
