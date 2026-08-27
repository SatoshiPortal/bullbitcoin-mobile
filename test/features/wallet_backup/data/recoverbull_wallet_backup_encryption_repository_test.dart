import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repository = RecoverBullWalletBackupEncryptionRepository();
  final key = WalletBackupEncryptionKey(
    '1111111111111111111111111111111111111111111111111111111111111111',
  );
  final wrongKey = WalletBackupEncryptionKey(
    '2222222222222222222222222222222222222222222222222222222222222222',
  );

  test('authenticates and decrypts a wallet backup envelope', () {
    final encrypted = repository.encrypt(envelope: _envelope(), key: key);
    final ciphertext = switch (encrypted) {
      Ok(:final value) => value,
      Err(:final failure) => fail('encryption failed: $failure'),
    };

    final decrypted = repository.decrypt(
      ciphertext: ciphertext,
      key: key,
      expectedParentFingerprint: 'fedcba98',
    );

    expect(decrypted, isA<Ok<WalletBackupEnvelope, WalletBackupFailure>>());
    expect(
      (decrypted as Ok<WalletBackupEnvelope, WalletBackupFailure>)
          .value
          .manifest
          .payload,
      _manifestPayload,
    );
  });

  test('hashes the canonical plaintext envelope deterministically', () {
    final first = repository.contentHash(_envelope());
    final second = repository.contentHash(_envelope());
    final firstHash = (first as Ok<String, WalletBackupFailure>).value;
    final secondHash = (second as Ok<String, WalletBackupFailure>).value;

    expect(firstHash, secondHash);
    expect(firstHash, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('rejects wrong keys and authenticated-ciphertext tampering', () {
    final encrypted = repository.encrypt(envelope: _envelope(), key: key);
    final ciphertext =
        (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>).value;
    final bytes = base64.decode(ciphertext.value)..[20] ^= 0xff;

    for (final attempt in [
      repository.decrypt(
        ciphertext: ciphertext,
        key: wrongKey,
        expectedParentFingerprint: 'fedcba98',
      ),
      repository.decrypt(
        ciphertext: WalletBackupCiphertext(base64.encode(bytes)),
        key: key,
        expectedParentFingerprint: 'fedcba98',
      ),
    ]) {
      expect(
        attempt,
        isA<Err<WalletBackupEnvelope, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupEncryptionFailure>(),
        ),
      );
    }
  });

  test('returns a typed mismatch after successful authentication', () {
    final encrypted = repository.encrypt(envelope: _envelope(), key: key);
    final ciphertext =
        (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>).value;

    final result = repository.decrypt(
      ciphertext: ciphertext,
      key: key,
      expectedParentFingerprint: '01234567',
    );

    expect(
      result,
      isA<Err<WalletBackupEnvelope, WalletBackupFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<WalletBackupParentFingerprintMismatchFailure>(),
      ),
    );
  });

  test('rejects oversized Base64 before decoding it', () {
    expect(
      () => WalletBackupCiphertext(
        'A' * (WalletBackupCiphertext.maximumEncodedLength + 1),
      ),
      throwsArgumentError,
    );
  });
}

const _manifestPayload =
    '{"version":1,"parentFingerprint":"fedcba98","generatedAt":1,'
    '"inventoryUpdatedAt":0,"entryCount":0,"materializationCount":0,'
    '"entries":[]}';

WalletBackupEnvelope _envelope() => WalletBackupEnvelope(
  parentFingerprint: 'fedcba98',
  createdAt: 2,
  manifest: WalletBackupManifestSection(
    payload: _manifestPayload,
    parentFingerprint: 'fedcba98',
  ),
);
