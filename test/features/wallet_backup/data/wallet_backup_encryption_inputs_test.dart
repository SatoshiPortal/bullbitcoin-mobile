import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an invalid encryption key is not embedded in its exception', () {
    final truncatedKey = 'a' * 63;
    expect(
      () => WalletBackupEncryptionKey(truncatedKey),
      throwsA(
        isA<ArgumentError>()
            .having((error) => error.invalidValue, 'invalid value', isNull)
            .having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains(truncatedKey)),
            ),
      ),
    );
  });

  test('a malformed ciphertext input is not echoed by its exception', () {
    const input = 'synthetic-private-input-in-wrong-field';
    expect(
      () => WalletBackupCiphertext(input),
      throwsA(
        isA<ArgumentError>()
            .having((error) => error.invalidValue, 'invalid value', isNull)
            .having(
              (error) => error.toString(),
              'diagnostic',
              isNot(contains(input)),
            ),
      ),
    );
  });

  test('valid encryption key normalization is unchanged', () {
    final key = WalletBackupEncryptionKey(' ${'AB' * 32} ');
    expect(key.hex, 'ab' * 32);
    expect(key.toString(), isNot(contains(key.hex)));
  });
}
