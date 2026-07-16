import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/derive_keychain_manifest_encryption_key_usecase.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('frozen 1642/0/1 path derives the expected separate encryption key', () {
    final mnemonic = bip39.Mnemonic.fromSentence(
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon about',
      bip39.Language.english,
    );
    final xprv = bip32.Bip32Keys.fromSeed(
      Uint8List.fromList(mnemonic.seed),
    ).toBase58();
    final parentFingerprint = bip32.Bip32Keys.fromBase58(xprv).fingerprintHex;

    final key = const DeriveKeychainManifestEncryptionKeyUsecase().execute(
      xprvBase58: xprv,
      expectedParentFingerprint: parentFingerprint,
    );

    expect(
      key.hex,
      '321154f080538350e83f2ebf866595a778ab671e55aacfe0638305ba95a48830',
    );
    expect(
      key.hex,
      isNot('feae6420b59badf72d7e85436ced2b0c3b9bcf4e46f05d901bf448f698f0ab52'),
    );
  });
}
