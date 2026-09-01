import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/data/recoverbull_wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/canonical_backup_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repository = RecoverBullWalletBackupEncryptionRepository(
    canonicalCodec(),
  );
  final key = WalletBackupEncryptionKey(
    '1111111111111111111111111111111111111111111111111111111111111111',
  );
  final wrongKey = WalletBackupEncryptionKey(
    '2222222222222222222222222222222222222222222222222222222222222222',
  );

  test('authenticates and decrypts a wallet backup envelope', () {
    final encrypted = repository.encrypt(
      envelope: canonicalMinimalSnapshot(),
      key: key,
    );
    final ciphertext = switch (encrypted) {
      Ok(:final value) => value,
      Err(:final failure) => fail('encryption failed: $failure'),
    };

    final decrypted = repository.decrypt(
      ciphertext: ciphertext,
      key: key,
      expectedParentFingerprint: 'deadbeef',
    );

    expect(decrypted, isA<Ok<WalletBackupSnapshot, WalletBackupFailure>>());
    expect(
      (decrypted as Ok<WalletBackupSnapshot, WalletBackupFailure>)
          .value
          .recoveryManifest
          .wallets
          .single
          .label,
      'Vacation',
    );
  });

  test('rejects wrong keys and authenticated-ciphertext tampering', () {
    final encrypted = repository.encrypt(
      envelope: canonicalMinimalSnapshot(),
      key: key,
    );
    final ciphertext =
        (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>).value;
    final bytes = base64.decode(ciphertext.value)..[20] ^= 0xff;

    for (final attempt in [
      repository.decrypt(
        ciphertext: ciphertext,
        key: wrongKey,
        expectedParentFingerprint: 'deadbeef',
      ),
      repository.decrypt(
        ciphertext: WalletBackupCiphertext(base64.encode(bytes)),
        key: key,
        expectedParentFingerprint: 'deadbeef',
      ),
    ]) {
      expect(
        attempt,
        isA<Err<WalletBackupSnapshot, WalletBackupFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<WalletBackupEncryptionFailure>(),
        ),
      );
    }
  });

  test('returns a typed mismatch after successful authentication', () {
    final encrypted = repository.encrypt(
      envelope: canonicalMinimalSnapshot(),
      key: key,
    );
    final ciphertext =
        (encrypted as Ok<WalletBackupCiphertext, WalletBackupFailure>).value;

    final result = repository.decrypt(
      ciphertext: ciphertext,
      key: key,
      expectedParentFingerprint: '01234567',
    );

    expect(
      result,
      isA<Err<WalletBackupSnapshot, WalletBackupFailure>>().having(
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
