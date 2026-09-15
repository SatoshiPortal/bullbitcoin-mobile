import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final network in [Network.bitcoinMainnet, Network.bitcoinTestnet]) {
    final privateKey = Bip32Derivation.getXprvFromSeed(
      Uint8List.fromList(List.generate(32, (index) => index)),
      network,
    );
    final inputs = {
      'private key': 'wpkh($privateKey/<0;1>/*)',
      'private key in unknown fragment': 'wsh($privateKey())',
      'private key in malformed timelock': 'wsh(after($privateKey))',
      'private key in invalid key origin':
          'wpkh([$privateKey]$privateKey/<0;1>/*)',
      'private key with broken parentheses': 'wpkh($privateKey/<0;1>/*',
    };

    test(
      '${network.name}: paired change input does not expose private keys',
      () {
        final publicKey = Bip32Derivation.deriveXpub(
          seedBytes: Uint8List.fromList(List.generate(32, (index) => index)),
          derivationPath: "m/84'/0'/0'",
          network: network,
        );
        expect(
          () => BdkFacade.combinePublicDescriptorPair(
            externalDescriptor: 'wpkh($publicKey/0/*)',
            internalDescriptor: 'wsh($privateKey())',
            isTestnet: network.isTestnet,
          ),
          throwsA(
            isA<FormatException>().having(
              (error) => error.toString().contains(privateKey),
              'private key appears in diagnostic',
              isFalse,
            ),
          ),
        );
      },
    );

    for (final entry in inputs.entries) {
      test('${network.name}: rejects ${entry.key} without exposing it', () {
        expect(
          () => BdkFacade.parsePublicTwoPathDescriptor(
            descriptor: entry.value,
            isTestnet: network.isTestnet,
          ),
          throwsA(
            isA<Exception>().having(
              (error) => error.toString().contains(privateKey),
              'private key appears in diagnostic',
              isFalse,
            ),
          ),
        );
      });
    }
  }
}
