import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import 'support/fakes.dart';
import 'support/inventory_fixture.dart';

// Published BIP39 test-vector account (abandon … about).
const _words = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];

const _fingerprint = '73c5da0a';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // A Liquid default derives its confidential descriptor through LWK, which
  // reaches the app's Rust bridge: without this the first Liquid creation
  // throws `Bad state: secrets: StateError` from `BaseEntrypoint._state`.
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);
  late Directory directory;
  late InventoryFixture fixture;
  late Secrets secrets;
  late WalletProvisioning accounts;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    directory = await Directory.systemTemp.createTemp('wallet-identity-');
    secrets = Secrets(scratchDirectory: () async => directory.path);
    fixture = await InventoryFixture.open(directory);
    accounts = WalletProvisioning.open(
      inventory: fixture.inventory,
      native: FakeNativeLifecycle(),
      resume: () async => const Ok(null),
      properties: const [],
    );
  });

  tearDown(() async {
    await fixture.close();
    await directory.delete(recursive: true);
  });

  Future<Secret> importSecret() async =>
      switch (await secrets.import(words: _words, language: Language.english)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('import: ${failure.runtimeType}'),
      };

  Future<RegisteredWallet> createDefault(Network network) async {
    final secret = await importSecret();
    expect(
      await accounts.createDefault(secret, network),
      isA<Ok<String, WalletProvisioningFailure>>(),
    );
    return switch (await fixture.inventory.listWallets()) {
      Ok(value: final wallets) => wallets.single,
      Err(:final failure) => fail('listWallets: $failure'),
    };
  }

  for (final (network, prefix, networkPath, code)
      in <(Network, String, String, String)>[
        (BitcoinNetwork.mainnet, 'wpkh(', '0h', 'bitcoinMainnet'),
        (BitcoinNetwork.testnet, 'wpkh(', '1h', 'bitcoinTestnet'),
        (BitcoinNetwork.regtest, 'wpkh(', '1h', 'bitcoinRegtest'),
        (LiquidNetwork.mainnet, 'elwpkh(', '1776h', 'liquidMainnet'),
        (LiquidNetwork.testnet, 'elwpkh(', '1h', 'liquidTestnet'),
        (LiquidNetwork.regtest, 'elwpkh(', '1h', 'liquidRegtest'),
      ]) {
    test('creation registers the storable identity on $network', () async {
      final row = await createDefault(network);
      final origin = '$prefix[$_fingerprint/84h/$networkPath/0h])';
      final suffixed = network.env == NetworkEnv.regtest;
      expect(row.id, suffixed ? '$origin:regtest' : origin);
      expect(row.id.endsWith(':regtest'), suffixed);
      expect(row.network, code);
      expect(row.signer, 'local');
      expect(row.masterFingerprint, _fingerprint);
      expect(row.secretFingerprint, _fingerprint);
      expect(row.isDefault, isTrue);
      expect(row.birthday, isNull);
    });
  }

  test(
    'regtest has a distinct id and the same unsuffixed derivation origin',
    () async {
      final secret = await importSecret();
      expect(
        await accounts.createDefault(secret, BitcoinNetwork.regtest),
        isA<Ok<String, WalletProvisioningFailure>>(),
      );
      final row = switch (await fixture.inventory.listWallets()) {
        Ok(value: final wallets) => wallets.single,
        Err(:final failure) => fail('listWallets: $failure'),
      };
      const origin = 'wpkh([$_fingerprint/84h/1h/0h])';
      expect(row.id, '$origin:regtest');

      // The unsuffixed form is the testnet identity, never a created row: an
      // unresolved regtest id must not resolve to a wallet.
      expect(
        await fixture.inventory.findWallet(origin),
        isA<Ok<RegisteredWallet?, SecretFailure>>().having(
          (result) => result.value,
          'row',
          isNull,
        ),
      );
    },
  );
}
