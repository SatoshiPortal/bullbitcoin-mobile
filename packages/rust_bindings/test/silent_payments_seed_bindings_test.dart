import 'dart:io';
import 'dart:typed_data';

import 'package:rust_bindings/rust_bindings.dart';
import 'package:rust_bindings/bwk.dart';
import 'package:flutter_test/flutter_test.dart';

// Published, funds-free BIP39 vectors; shared with seed_bindings_test.dart.
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

const _englishSpAddress =
    'tsp1qqdpels3srq45dlezqvk20t3dlueftry6p5thc7msjm0s6jm3g84jzq5rxzzunfck6d45va2jcqxk429agt3e4klf3vzmcgp3zqthryhhqgnz4k3n';

Uint8List _seed(String hex) => Uint8List.fromList([
  for (var offset = 0; offset < hex.length; offset += 2)
    int.parse(hex.substring(offset, offset + 2), radix: 16),
]);

Future<void> _close(SpAccount account) async {
  await account.dispose();
  await account.release();
  expect(account.isDisposed, isTrue);
}

void main() {
  late Directory scratch;
  setUpAll(() async {
    // Required compatibility gate: the hook-built library must load.
    await BullSdk.init();
  });
  tearDownAll(BullSdk.dispose);
  setUp(() async {
    scratch = await Directory.systemTemp.createTemp('sdk_sp_seed_');
  });
  tearDown(() async => scratch.delete(recursive: true));

  Future<SpAccount> fromSeed(String seed, String directory) =>
      SpAccount.createFromSeedWithScanRuntime(
        name: 'seed-vector',
        network: SpNetwork.signet,
        seed: _seed(seed),
        blindbitUrl: 'http://127.0.0.1:1',
        electrumUrl: '',
        dataDir: '${scratch.path}/$directory',
        fetchConcurrencyFactor: 1,
        matchConcurrencyFactor: 1,
      );

  test(
    'English seed preserves mnemonic address and reopening identity',
    () async {
      final publicAddress = await deriveSpAddressFromSeed(
        seed: _seed(_englishSeedHex),
        network: SpNetwork.signet,
      );
      expect(publicAddress == _englishSpAddress, isTrue);
      final words = await SpAccount.createFromMnemonicWithScanRuntime(
        name: 'words-vector',
        network: SpNetwork.signet,
        mnemonic: _englishWords,
        blindbitUrl: 'http://127.0.0.1:1',
        electrumUrl: '',
        dataDir: '${scratch.path}/words',
        fetchConcurrencyFactor: 1,
        matchConcurrencyFactor: 1,
      );
      final seed = await fromSeed(_englishSeedHex, 'english');
      late String address;
      try {
        address = seed.spAddress();
        expect(address == _englishSpAddress, isTrue);
        // Boolean assertion avoids including addresses in a failed-test log.
        expect(address == words.spAddress(), isTrue);
      } finally {
        await _close(words);
        await _close(seed);
      }
      for (var iteration = 0; iteration < 10; iteration++) {
        final reopened = await fromSeed(_englishSeedHex, 'english');
        try {
          expect(reopened.spAddress() == address, isTrue);
        } finally {
          await _close(reopened);
        }
      }
    },
  );

  test('French and passphrase seeds select distinct stable accounts', () async {
    final addresses = <String>{};
    for (final vector in [
      (seed: _englishSeedHex, directory: 'english'),
      (seed: _frenchSeedHex, directory: 'french'),
      (seed: _englishTrezorSeedHex, directory: 'passphrase'),
    ]) {
      final publicAddress = await deriveSpAddressFromSeed(
        seed: _seed(vector.seed),
        network: SpNetwork.signet,
      );
      final account = await fromSeed(vector.seed, vector.directory);
      late String address;
      try {
        address = account.spAddress();
        expect(address == publicAddress, isTrue);
        expect(address.startsWith('tsp1'), isTrue);
        expect(addresses.add(address), isTrue);
      } finally {
        await _close(account);
      }
      final reopened = await fromSeed(vector.seed, vector.directory);
      try {
        expect(reopened.spAddress() == address, isTrue);
      } finally {
        await _close(reopened);
      }
    }
  });
}
