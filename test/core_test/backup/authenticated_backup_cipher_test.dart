import 'dart:convert';

import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = AuthenticatedBackupCipherKey(
    '1111111111111111111111111111111111111111111111111111111111111111',
  );
  const cipher = RecoverBullAuthenticatedBackupCipher();

  test('round-trips RecoverBull-compatible authenticated ciphertext', () {
    final encrypted = cipher.encrypt(plaintext: 'manifest', key: key);

    expect(cipher.decrypt(ciphertext: encrypted, key: key), 'manifest');
    expect(encrypted.byteLength, greaterThanOrEqualTo(64));
  });

  test('decrypts the frozen AES-CBC/HMAC wire vector', () {
    final ciphertext = AuthenticatedBackupCiphertext(
      'AAECAwQFBgcICQoLDA0OD8zcb2POSZTyA0LuNJmAMoGjZV44Rx1V/TmdaiNP'
      'BusVRuTTBEsvA+dhMBBl2d2DaA==',
    );

    expect(cipher.decrypt(ciphertext: ciphertext, key: key), 'manifest');
  });

  test('rejects wrong keys and mutations', () {
    final encrypted = cipher.encrypt(plaintext: 'manifest', key: key);
    final bytes = base64.decode(encrypted.value)..[20] ^= 0xff;

    expect(
      () => cipher.decrypt(
        ciphertext: encrypted,
        key: AuthenticatedBackupCipherKey(
          '2222222222222222222222222222222222222222222222222222222222222222',
        ),
      ),
      throwsA(isA<AuthenticatedBackupCipherException>()),
    );
    expect(
      () => cipher.decrypt(
        ciphertext: AuthenticatedBackupCiphertext(base64.encode(bytes)),
        key: key,
      ),
      throwsA(isA<AuthenticatedBackupCipherException>()),
    );
  });

  test('requires canonical base64 and enforces the decoded size bound', () {
    expect(
      () => AuthenticatedBackupCiphertext(
        '${base64.encode(List.filled(64, 0))}\n',
      ),
      throwsA(isA<AuthenticatedBackupCipherException>()),
    );
    expect(
      () => AuthenticatedBackupCiphertext(
        base64.encode(
          List.filled(AuthenticatedBackupCiphertext.maximumByteLength + 1, 0),
        ),
      ),
      throwsA(isA<AuthenticatedBackupCipherException>()),
    );
  });
}
