import 'dart:typed_data';

import 'package:bb_mobile/core/utils/recoverbull_encryption.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:convert/convert.dart';
import 'package:recoverbull/recoverbull.dart';

void main() {
  const encryption = RecoverBullEncryption();
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  final rejects = throwsA(isA<RecoverBullEncryptionException>());

  for (final length in [1, 15, 16, 17, 65536, 1048576]) {
    test('RecoverBull API interoperability for $length bytes', () async {
      final plaintext = Uint8List.fromList(
        List.generate(length, (i) => i % 251),
      );
      final encrypted = await encryption.encrypt(key, plaintext);
      expect(encrypted.length, 48 + (length ~/ 16 + 1) * 16);
      expect(
        RecoverBull.restoreBackup(
          backup: BullBackup(
            createdAt: 0,
            id: const [],
            salt: const [],
            ciphertext: encrypted,
          ),
          backupKey: key,
        ),
        orderedEquals(plaintext),
      );
      final external = RecoverBull.createBackup(
        secret: plaintext,
        backupKey: key,
      );
      expect(
        await encryption.decrypt(key, Uint8List.fromList(external.ciphertext)),
        orderedEquals(plaintext),
      );
    });
  }

  test('reads independent Python AES-CBC/HMAC fixture', () async {
    // Python cryptography AES-CBC/PKCS7 and hashlib HMAC-SHA256;
    // public key 00..1f, IV 00..0f, plaintext 00..20 (33 bytes).
    final external = Uint8List.fromList(
      hex.decode(
        '000102030405060708090a0b0c0d0e0ff29000b62a499fd0a9f39a6add2e77809543b86fc046fa883a9446b82e47d12d07f9ad8db02565e07f457639d176c7669779d0981274b3a2f9d7d8b6c9b4a0095a313a7b32df9e3c75ede53683d69a4f',
      ),
    );
    expect(
      await encryption.decrypt(key, external),
      orderedEquals(List.generate(33, (i) => i)),
    );
  });

  test('fresh IVs and authenticated rejection of every wire section', () async {
    final plaintext = Uint8List.fromList(List.filled(100, 42));
    final ciphertext = await encryption.encrypt(key, plaintext);
    expect(
      await encryption.encrypt(key, plaintext),
      isNot(orderedEquals(ciphertext)),
    );
    for (final index in [
      0,
      15,
      16,
      ciphertext.length - 33,
      ciphertext.length - 32,
      ciphertext.length - 1,
    ]) {
      final changed = Uint8List.fromList(ciphertext)..[index] ^= 1;
      await expectLater(encryption.decrypt(key, changed), rejects);
    }
    await expectLater(encryption.decrypt(Uint8List(32), ciphertext), rejects);
    for (final length in [
      0,
      1,
      47,
      48,
      63,
      ciphertext.length - 1,
      ciphertext.length - 16,
    ]) {
      await expectLater(
        encryption.decrypt(key, Uint8List.sublistView(ciphertext, 0, length)),
        rejects,
      );
    }
    await expectLater(
      encryption.decrypt(
        key,
        Uint8List.fromList([...ciphertext, ...List.filled(16, 0)]),
      ),
      rejects,
    );
  });

  test('size and key bounds reject before cryptographic work', () async {
    for (final length in [0, RecoverBullEncryption.maxPlaintextBytes + 1]) {
      await expectLater(encryption.encrypt(key, Uint8List(length)), rejects);
    }
    await expectLater(
      encryption.decrypt(
        key,
        Uint8List(RecoverBullEncryption.maxCiphertextBytes + 1),
      ),
      rejects,
    );
    for (final length in [0, 16, 31, 33]) {
      await expectLater(
        encryption.encrypt(Uint8List(length), Uint8List(1)),
        rejects,
      );
      await expectLater(
        encryption.decrypt(Uint8List(length), Uint8List(64)),
        rejects,
      );
    }
  });

  test('rejects authenticated plaintext beyond the limit', () async {
    // One extra plaintext byte still fits the maximum padded ciphertext size.
    final external = RecoverBull.createBackup(
      secret: Uint8List(RecoverBullEncryption.maxPlaintextBytes + 1),
      backupKey: key,
    );
    expect(
      external.ciphertext.length,
      RecoverBullEncryption.maxCiphertextBytes,
    );
    await expectLater(
      encryption.decrypt(key, Uint8List.fromList(external.ciphertext)),
      rejects,
    );
  });

  test('async operations snapshot mutable caller input and key', () async {
    final original = Uint8List.fromList([1, 2, 3]);
    final mutableKey = Uint8List.fromList(key);
    final mutableInput = Uint8List.fromList(original);
    final pending = encryption.encrypt(mutableKey, mutableInput);
    mutableKey.fillRange(0, mutableKey.length, 0);
    mutableInput.fillRange(0, mutableInput.length, 0);
    final encrypted = await pending;
    final decryptKey = Uint8List.fromList(key);
    final decrypting = encryption.decrypt(decryptKey, encrypted);
    encrypted.fillRange(0, encrypted.length, 0);
    decryptKey.fillRange(0, decryptKey.length, 0);
    expect(await decrypting, orderedEquals(original));
    expect(key, orderedEquals(List.generate(32, (i) => i)));
  });
}
