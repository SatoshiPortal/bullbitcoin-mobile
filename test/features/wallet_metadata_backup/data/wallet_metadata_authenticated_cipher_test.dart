import 'dart:convert';

import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_authenticated_cipher.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encryption_key.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cipher = WalletMetadataAuthenticatedCipher();
  final key = WalletMetadataEncryptionKey('11' * 32);
  final wrongKey = WalletMetadataEncryptionKey('22' * 32);

  test('round-trips authenticated ciphertext and rejects a wrong key', () {
    final encrypted = cipher.encrypt(plaintext: 'metadata', key: key);

    expect(cipher.decrypt(ciphertext: encrypted, key: key), 'metadata');
    expect(
      () => cipher.decrypt(ciphertext: encrypted, key: wrongKey),
      throwsA(isA<WalletMetadataCipherException>()),
    );
  });

  test('rejects mutation and oversized decoded ciphertext', () {
    final bytes = base64.decode(
      cipher.encrypt(plaintext: 'metadata', key: key),
    );
    bytes[20] ^= 1;
    expect(
      () => cipher.decrypt(ciphertext: base64.encode(bytes), key: key),
      throwsA(isA<WalletMetadataCipherException>()),
    );
    expect(
      () => cipher.decrypt(
        ciphertext: base64.encode(
          List.filled(WalletMetadataBackupLimits.maxCiphertextBytes + 1, 0),
        ),
        key: key,
      ),
      throwsA(isA<WalletMetadataCipherException>()),
    );
  });
}
