import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/recoverbull_bip85.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mnemonic = Mnemonic.fromWords(
    words: List.generate(11, (index) => 'zoo') + ['wrong'],
  );
  final xprv = Bip32Derivation.getXprvFromSeed(
    Uint8List.fromList(mnemonic.seed),
    Network.bitcoinMainnet,
  );

  final validRecoverbullCustomPaths = [
    "m/1608'/0'/586053381",
    "1608'/0'/586053381",
  ];

  const expectedKeyForPath =
      '151a5a41f5eac5d49e67e0fad0bddd3beebe0f0e4b7739435997506cf12d9fce';

  group('Recoverbull Bip85', () {
    for (final path in validRecoverbullCustomPaths) {
      test('deriveBackupKey', () {
        final derivedKey = RecoverbullBip85Utils.deriveBackupKey(xprv, path);
        expect(derivedKey, expectedKeyForPath);
      });
    }
  });
}
