import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_key_deriver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const deriver = WalletMetadataKeyDeriver();

  test('freezes the metadata encryption key', () {
    final key = deriver.deriveEncryptionKey(
      xprvBase58: _masterXprv,
      expectedParentFingerprint: _parentFingerprint,
    );

    expect(
      key.hex,
      'a26bad6f943b78ea4d685ab00eac75407f9cb642b106b8a44c0597bc3f7a256f',
    );
    expect(key.toString(), isNot(contains(key.hex)));
  });

  test('rejects a parent mismatch before deriving metadata material', () {
    expect(
      () => deriver.deriveEncryptionKey(
        xprvBase58: _masterXprv,
        expectedParentFingerprint: 'ffffffff',
      ),
      throwsA(isA<WalletMetadataKeyDerivationException>()),
    );
  });

  test('maps a malformed xprv to a key derivation exception', () {
    expect(
      () => deriver.deriveEncryptionKey(
        xprvBase58: 'not-an-xprv',
        expectedParentFingerprint: _parentFingerprint,
      ),
      throwsA(isA<WalletMetadataKeyDerivationException>()),
    );
  });
}

const _masterXprv =
    'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb';
const _parentFingerprint = '627ef3a6';
