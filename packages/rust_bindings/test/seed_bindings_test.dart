import 'dart:typed_data';

import 'package:rust_bindings/boltz.dart' as boltz;
import 'package:rust_bindings/rust_bindings.dart';
import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:flutter_test/flutter_test.dart';

// The seed-based Liquid and Boltz bindings, exercised over the host library:
// for an English mnemonic they give exactly what the word-based constructors
// give, and the same entropy in French gives another wallet.
//
// BIP39 fixtures: entropy 0x00 * 16. The English seeds are the published
// BIP39 vectors (empty passphrase, and "TREZOR"); the French seed was computed
// with a stdlib PBKDF2-HMAC-SHA512 over the NFKD sentence.
//
// Loads the library the Native Assets hook builds for the host.
const _englishWords =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';
const _englishSeedHex =
    '5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc1'
    '9a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4';
const _englishTrezorSeedHex =
    'c55257c360c07c72029aebc1b53c05ed0362ada38ead3e3e9efa3708e5349553'
    '1f09a6987599d18264c1e1c92f2cf141630c7a3c4ab7c81b2f001698e7463b04';
const _frenchSeedHex =
    '01051dcfa9e1695ca99d1bd2a3304d073c00d275ad5a389d0579a13f4f8e90e5'
    '12f0c5839764179926bf51961d84c3bf3e20404298065998c60e43e4ec7985b6';

Uint8List _hex(String hex) => Uint8List.fromList([
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
]);

void main() {
  setUpAll(BullSdk.init);

  group('Liquid descriptor from a seed', () {
    for (final network in [
      lwk.LiquidNetwork.mainnet,
      lwk.LiquidNetwork.testnet,
    ]) {
      test(
        'equals the English mnemonic descriptor on ${network.name}',
        () async {
          final fromWords = await lwk.Descriptor.newConfidential(
            network: network,
            mnemonic: _englishWords,
          );
          final fromSeed = await lwk.Descriptor.newConfidentialFromSeed(
            network: network,
            seed: _hex(_englishSeedHex),
          );
          expect(fromSeed.ctDescriptor, fromWords.ctDescriptor);
        },
      );
    }

    test('differs for the same entropy in French', () async {
      final english = await lwk.Descriptor.newConfidentialFromSeed(
        network: lwk.LiquidNetwork.mainnet,
        seed: _hex(_englishSeedHex),
      );
      final french = await lwk.Descriptor.newConfidentialFromSeed(
        network: lwk.LiquidNetwork.mainnet,
        seed: _hex(_frenchSeedHex),
      );
      expect(french.ctDescriptor, isNot(english.ctDescriptor));
    });
  });

  group('Boltz swap master key from a seed', () {
    test(
      'equals the English mnemonic key, with and without passphrase',
      () async {
        for (final (passphrase, seedHex) in [
          (null, _englishSeedHex),
          ('TREZOR', _englishTrezorSeedHex),
        ]) {
          final fromWords = await boltz.SwapMasterKey.create(
            walletMnemonic: _englishWords,
            walletPassphrase: passphrase,
            network: boltz.Network.mainnet,
          );
          final fromSeed = await boltz.SwapMasterKey.createFromSeed(
            seed: _hex(seedHex),
            network: boltz.Network.mainnet,
          );
          expect(fromSeed.mnemonic, fromWords.mnemonic);
          expect(fromSeed.xprv, fromWords.xprv);
          expect(fromSeed.xpub, fromWords.xpub);
          expect(fromSeed.fingerprint, fromWords.fingerprint);
        }
      },
    );

    test('differs for the same entropy in French', () async {
      final english = await boltz.SwapMasterKey.createFromSeed(
        seed: _hex(_englishSeedHex),
        network: boltz.Network.mainnet,
      );
      final french = await boltz.SwapMasterKey.createFromSeed(
        seed: _hex(_frenchSeedHex),
        network: boltz.Network.mainnet,
      );
      expect(french.mnemonic, isNot(english.mnemonic));
      expect(french.xprv, isNot(english.xprv));
    });
  });
}
