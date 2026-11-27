import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';
import 'package:rust_bindings/rust_bindings.dart' show BullSdk;
import 'package:satoshifier/bip32_derivation.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:secrets/testing.dart';

import 'support/fakes.dart';
import 'support/inventory_fixture.dart';

/// The identity an upgraded install must find again.
///
/// A wallet is keyed by `origin(fingerprint, network, scriptType)`, and
/// `xpubFingerprint` joins it to everything derived from it. Both are now
/// computed by `package:provisioning` where the deleted app helpers used to
/// be. This pins the composite the app actually stores, for every network and
/// script type, so the next refactor that moves either value goes red here
/// instead of orphaning rows in the field — which the code itself records an
/// earlier attempt did for every Liquid wallet.
///
/// The literals were produced by the previous implementation on 2026-09-23 from
/// the published `abandon … about` mnemonic: a regression pin, not an external
/// anchor. Liquid testnet and Bitcoin testnet coincide by design — both are
/// coin type 1; Liquid mainnet is 1776 and does not.
void main() {
  const words = [
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
  const fingerprint = '73c5da0a';

  const expected =
      <
        (Network, ScriptType),
        ({String id, String xpubFingerprint, String xpub})
      >{
        (BitcoinNetwork.mainnet, ScriptType.bip84): (
          id: 'wpkh([73c5da0a/84h/0h/0h])',
          xpubFingerprint: 'fd13aac9',
          xpub: 'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
        ),
        (BitcoinNetwork.mainnet, ScriptType.bip49): (
          id: 'sh(wpkh([73c5da0a/49h/0h/0h]))',
          xpubFingerprint: '3a161284',
          xpub: 'ypub6Ww3ibxVfGzLrAH1PNcjyAWenMTbbAosGNB6VvmSEgytSER9azLDWCxoJwW7Ke7icmizBMXrzBx9979FfaHxHcrArf3zbeJJJUZPf663zsP',
        ),
        (BitcoinNetwork.mainnet, ScriptType.bip44): (
          id: 'pkh([73c5da0a/44h/0h/0h])',
          xpubFingerprint: '6cc9f252',
          xpub: 'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
        ),
        (BitcoinNetwork.testnet, ScriptType.bip84): (
          id: 'wpkh([73c5da0a/84h/1h/0h])',
          xpubFingerprint: 'e99b8628',
          xpub: 'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
        ),
        (BitcoinNetwork.testnet, ScriptType.bip49): (
          id: 'sh(wpkh([73c5da0a/49h/1h/0h]))',
          xpubFingerprint: '0a55db61',
          xpub: 'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
        ),
        (BitcoinNetwork.testnet, ScriptType.bip44): (
          id: 'pkh([73c5da0a/44h/1h/0h])',
          xpubFingerprint: '4334c988',
          xpub: 'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
        ),
        (LiquidNetwork.mainnet, ScriptType.bip84): (
          id: 'elwpkh([73c5da0a/84h/1776h/0h])',
          xpubFingerprint: '5a00fb4f',
          xpub: 'zpub6r5nbp27YaffuknV3Egk4fLJiKWKTqp6CmVGZHLukWsvUfqAiwyuziKxED9juLgQQLB16xdcXYEmycB4Ws1v44W4rrF1mHPmxrG8ZBQ81RP',
        ),
        (LiquidNetwork.mainnet, ScriptType.bip49): (
          id: 'elsh(wpkh([73c5da0a/49h/1776h/0h]))',
          xpubFingerprint: '9440847f',
          xpub: 'ypub6XBkfpSgdJb4VpYQruPwT2wVLcCPxzP8BaY9iiETxA8DUx5JsDgJTA8CewM29eZjHQgLNpnTqg4kLmTVgYueCgLUtY7JjecfbUuwLNiD9jQ',
        ),
        (LiquidNetwork.mainnet, ScriptType.bip44): (
          id: 'elpkh([73c5da0a/44h/1776h/0h])',
          xpubFingerprint: '4a2bf7b0',
          xpub: 'xpub6CCvPyUQu45XbhPWrcuDL26MUXcdu9A9GQoTzDqqt1H4qdy7w5ptAjAxDkuB7c6af2wJ94KHXEkWun3NzwwTGnttosfJ2RUsdBmsABW5EU6',
        ),
        (LiquidNetwork.testnet, ScriptType.bip84): (
          id: 'elwpkh([73c5da0a/84h/1h/0h])',
          xpubFingerprint: 'e99b8628',
          xpub: 'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
        ),
        (LiquidNetwork.testnet, ScriptType.bip49): (
          id: 'elsh(wpkh([73c5da0a/49h/1h/0h]))',
          xpubFingerprint: '0a55db61',
          xpub: 'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
        ),
        (LiquidNetwork.testnet, ScriptType.bip44): (
          id: 'elpkh([73c5da0a/44h/1h/0h])',
          xpubFingerprint: '4334c988',
          xpub: 'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
        ),

        // Regtest keeps coin type 1 derivation; Bitcoin regtest creation
        // policy separately refuses legacy scripts. Internal regtest ids add a
        // suffix.
        (BitcoinNetwork.regtest, ScriptType.bip84): (
          id: 'wpkh([73c5da0a/84h/1h/0h])',
          xpubFingerprint: 'e99b8628',
          xpub: 'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
        ),
        (BitcoinNetwork.regtest, ScriptType.bip49): (
          id: 'sh(wpkh([73c5da0a/49h/1h/0h]))',
          xpubFingerprint: '0a55db61',
          xpub: 'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
        ),
        (BitcoinNetwork.regtest, ScriptType.bip44): (
          id: 'pkh([73c5da0a/44h/1h/0h])',
          xpubFingerprint: '4334c988',
          xpub: 'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
        ),
        (LiquidNetwork.regtest, ScriptType.bip84): (
          id: 'elwpkh([73c5da0a/84h/1h/0h])',
          xpubFingerprint: 'e99b8628',
          xpub: 'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
        ),
        (LiquidNetwork.regtest, ScriptType.bip49): (
          id: 'elsh(wpkh([73c5da0a/49h/1h/0h]))',
          xpubFingerprint: '0a55db61',
          xpub: 'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
        ),
        (LiquidNetwork.regtest, ScriptType.bip44): (
          id: 'elpkh([73c5da0a/44h/1h/0h])',
          xpubFingerprint: '4334c988',
          xpub: 'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
        ),
      };

  late Directory directory;
  late InventoryFixture fixture;
  late Secrets secrets;
  late FakeAdmission admission;
  late WalletProvisioning accounts;
  late Secret secret;

  // A Liquid default derives its confidential descriptor through LWK, which
  // reaches the app's Rust bridge: without this the Liquid BIP84 creation
  // throws `Bad state: secrets: StateError` from `BaseEntrypoint._state`.
  setUpAll(BullSdk.init);
  tearDownAll(BullSdk.dispose);

  setUp(() async {
    FakeSecureStoragePlatform().install();
    directory = await Directory.systemTemp.createTemp('identity-pins-');
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    secret = switch (await secrets.import(
      words: words,
      language: Language.english,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => fail('import: ${failure.runtimeType}'),
    };
    expect(secret.id.hex, fingerprint);
    fixture = await InventoryFixture.open(directory);
    admission = FakeAdmission();
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

  test('every creation-supported network and script type is covered', () {
    expect(expected.length, 18);
    expect(
      expected.keys.map((key) => key.$1).toSet(),
      hasLength(6),
      reason: 'every network the app can name',
    );
    expect(
      expected.keys.map((key) => key.$2).toSet(),
      ScriptType.values.toSet(),
    );
  });

  for (final entry in expected.entries) {
    final (network, scriptType) = entry.key;
    final registeredId = network.env == NetworkEnv.regtest
        ? '${entry.value.id}:regtest'
        : entry.value.id;
    // Creation policy refuses legacy scripts on regtest; the identity is still
    // pinned by the derivation, and the refusal is explicit rather than silent.
    final refused =
        network == BitcoinNetwork.regtest && scriptType != ScriptType.bip84;

    test('$network / $scriptType', () async {
      final xpub = switch (await secret.derive.xpub(
        network: network,
        scriptType: scriptType,
      )) {
        Ok(:final value) => value,
        Err(:final failure) => fail('xpub: ${failure.runtimeType}'),
      };
      expect(xpub, entry.value.xpub);
      expect(
        Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
        entry.value.xpubFingerprint,
      );

      final BitcoinNetwork bitcoin;
      switch (network) {
        case BitcoinNetwork():
          bitcoin = network;
        case LiquidNetwork():
          // Liquid accounts are only created as the default BIP84 account;
          // other script types keep their derivation pins above.
          if (scriptType != ScriptType.bip84) return;
          final created = await accounts.createDefault(secret, network);
          expect(created, isA<Ok<String, WalletProvisioningFailure>>());
          final row = switch (await fixture.inventory.findWallet(
            registeredId,
          )) {
            Ok(:final value) => value,
            Err(:final failure) => fail('findWallet: $failure'),
          };
          expect(row?.id, registeredId);
          expect(row?.masterFingerprint, fingerprint);
          expect(row?.secretFingerprint, fingerprint);
          expect(row?.signer, 'local');
          return;
      }
      final import = accounts.importMnemonic(
        parent: secret.id,
        secrets: secrets,
        admission: admission,
        network: bitcoin,
        scriptType: scriptType,
        label: null,
      );
      if (refused) {
        await expectLater(
          import,
          throwsA(
            isA<WalletProvisioningException>().having(
              (error) => error.failure,
              'failure',
              isA<WalletProvisioningUnsupportedFailure>(),
            ),
          ),
        );
        final missing = await fixture.inventory.findWallet(registeredId);
        expect(
          missing,
          isA<Ok<RegisteredWallet?, SecretFailure>>().having(
            (result) => result.value,
            'row',
            isNull,
          ),
        );
        return;
      }
      expect(await import, isA<Ok<void, ParentCustodyFailure>>());
      final row = switch (await fixture.inventory.findWallet(registeredId)) {
        Ok(:final value) => value,
        Err(:final failure) => fail('findWallet: $failure'),
      };
      expect(row, isNotNull);
      expect(row?.id, registeredId);
      expect(row?.masterFingerprint, fingerprint);
      expect(row?.secretFingerprint, fingerprint);
      expect(row?.signer, 'local');
    });
  }
}
