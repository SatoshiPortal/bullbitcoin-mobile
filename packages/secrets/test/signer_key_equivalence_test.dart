import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/derivers/derivers.dart' show Deriver;
import 'package:secrets/src/data/secret_repository.dart' show SecretRepository;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// The signer used to build its master key from bdk's own BIP39 (`Mnemonic` + password); it now takes the Dart seed through `masterXprv`, as the public descriptors always did. Every English secret already stored must sign with the very same key, on every network and with every kind of passphrase. Script types share `privateDescriptor` over this key, so equal keys mean equal descriptors for BIP84, BIP49 and BIP44.
void main() {
  const words = [
    'legal',
    'winner',
    'thank',
    'year',
    'wave',
    'sausage',
    'worth',
    'useful',
    'legal',
    'winner',
    'thank',
    'yellow',
  ];

  const passphrases = {
    'none': '',
    'ascii': 'TREZOR',
    'surrounding spaces': '  pass phrase  ',
    'precomposed é': 'café',
    'decomposed é': 'café',
    'compatibility ligature': 'ﬁnance',
  };

  setUp(() => FakeSecureStoragePlatform().install());

  for (final MapEntry(key: label, value: passphrase) in passphrases.entries) {
    for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
      test('$label passphrase on ${network.name}: same signing key', () async {
        final repo = SecretRepository();
        final info = ok(
          await repo.store(
            words: words,
            passphrase: passphrase.isEmpty ? null : passphrase,
          ),
        );
        final secret = ok(await repo.use(info, (m) => m));

        final mnemonic = bdk.Mnemonic.fromString(mnemonic: words.join(' '));
        final before = bdk.DescriptorSecretKey(
          networkKind: network.isMainnet
              ? bdk.NetworkKind.main
              : bdk.NetworkKind.test,
          mnemonic: mnemonic,
          password: passphrase.isEmpty ? null : passphrase,
        );
        final after = bdk.DescriptorSecretKey.fromString(
          privateKey: Deriver.bitcoin.masterXprv(secret, network),
        );
        addTearDown(() {
          after.dispose();
          before.dispose();
          mnemonic.dispose();
        });

        expect(after.toString(), before.toString());
      });
    }
  }
}
