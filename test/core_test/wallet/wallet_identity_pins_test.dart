import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/network_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/wallet_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' as p;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

/// The identity an upgraded install must find again.
///
/// A wallet row is keyed by `id` — `encodeOrigin(fingerprint, network,
/// scriptType)` — and `xpubFingerprint` joins it to everything derived from
/// it. Both are now computed by `package:secrets` where deleted app helpers
/// used to be; two independent readers established that no value moved,
/// and bdk agrees with every xpub the package derives
/// (`packages/secrets/test/derivation_mappings_test.dart`). This pins the
/// composite the app actually stores, for every network and script type,
/// so the next refactor that moves either value goes red here instead of
/// orphaning rows in the field — which the code itself records an earlier
/// attempt did for every Liquid wallet.
///
/// The literals were produced by this implementation on 2026-09-23 from
/// the published `abandon … about` mnemonic: a regression pin, not an
/// external anchor. Liquid testnet and Bitcoin testnet coincide by design —
/// both are coin type 1; Liquid mainnet is 1776 and does not.
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

  const expected = <(Network, ScriptType), ({String id, String xpubFingerprint, String xpub})>{
    (Network.bitcoinMainnet, ScriptType.bip84): (
      id: 'wpkh([73c5da0a/84h/0h/0h])',
      xpubFingerprint: 'fd13aac9',
      xpub:
          'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
    ),
    (Network.bitcoinMainnet, ScriptType.bip49): (
      id: 'sh(wpkh([73c5da0a/49h/0h/0h]))',
      xpubFingerprint: '3a161284',
      xpub:
          'ypub6Ww3ibxVfGzLrAH1PNcjyAWenMTbbAosGNB6VvmSEgytSER9azLDWCxoJwW7Ke7icmizBMXrzBx9979FfaHxHcrArf3zbeJJJUZPf663zsP',
    ),
    (Network.bitcoinMainnet, ScriptType.bip44): (
      id: 'pkh([73c5da0a/44h/0h/0h])',
      xpubFingerprint: '6cc9f252',
      xpub:
          'xpub6BosfCnifzxcFwrSzQiqu2DBVTshkCXacvNsWGYJVVhhawA7d4R5WSWGFNbi8Aw6ZRc1brxMyWMzG3DSSSSoekkudhUd9yLb6qx39T9nMdj',
    ),
    (Network.bitcoinTestnet, ScriptType.bip84): (
      id: 'wpkh([73c5da0a/84h/1h/0h])',
      xpubFingerprint: 'e99b8628',
      xpub:
          'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
    ),
    (Network.bitcoinTestnet, ScriptType.bip49): (
      id: 'sh(wpkh([73c5da0a/49h/1h/0h]))',
      xpubFingerprint: '0a55db61',
      xpub:
          'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
    ),
    (Network.bitcoinTestnet, ScriptType.bip44): (
      id: 'pkh([73c5da0a/44h/1h/0h])',
      xpubFingerprint: '4334c988',
      xpub:
          'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
    ),
    (Network.liquidMainnet, ScriptType.bip84): (
      id: 'elwpkh([73c5da0a/84h/1776h/0h])',
      xpubFingerprint: '5a00fb4f',
      xpub:
          'zpub6r5nbp27YaffuknV3Egk4fLJiKWKTqp6CmVGZHLukWsvUfqAiwyuziKxED9juLgQQLB16xdcXYEmycB4Ws1v44W4rrF1mHPmxrG8ZBQ81RP',
    ),
    (Network.liquidMainnet, ScriptType.bip49): (
      id: 'elsh(wpkh([73c5da0a/49h/1776h/0h]))',
      xpubFingerprint: '9440847f',
      xpub:
          'ypub6XBkfpSgdJb4VpYQruPwT2wVLcCPxzP8BaY9iiETxA8DUx5JsDgJTA8CewM29eZjHQgLNpnTqg4kLmTVgYueCgLUtY7JjecfbUuwLNiD9jQ',
    ),
    (Network.liquidMainnet, ScriptType.bip44): (
      id: 'elpkh([73c5da0a/44h/1776h/0h])',
      xpubFingerprint: '4a2bf7b0',
      xpub:
          'xpub6CCvPyUQu45XbhPWrcuDL26MUXcdu9A9GQoTzDqqt1H4qdy7w5ptAjAxDkuB7c6af2wJ94KHXEkWun3NzwwTGnttosfJ2RUsdBmsABW5EU6',
    ),
    (Network.liquidTestnet, ScriptType.bip84): (
      id: 'elwpkh([73c5da0a/84h/1h/0h])',
      xpubFingerprint: 'e99b8628',
      xpub:
          'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
    ),
    (Network.liquidTestnet, ScriptType.bip49): (
      id: 'elsh(wpkh([73c5da0a/49h/1h/0h]))',
      xpubFingerprint: '0a55db61',
      xpub:
          'upub5EFU65HtV5TeiSHmZZm7FUffBGy8UKeqp7vw43jYbvZPpoVsgU93oac7Wk3u6moKegAEWtGNF8DehrnHtv21XXEMYRUocHqguyjknFHYfgY',
    ),
    (Network.liquidTestnet, ScriptType.bip44): (
      id: 'elpkh([73c5da0a/44h/1h/0h])',
      xpubFingerprint: '4334c988',
      xpub:
          'tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba',
    ),
  };

  late Secret secret;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    secret = switch (await Secrets(
      scratchDirectory: () async => '/tmp',
    ).import(words: words)) {
      p.Ok(:final value) => value,
      p.Err(:final failure) => fail('import: ${failure.runtimeType}'),
    };
    expect(secret.id.hex, fingerprint);
  });

  test('every network and script type is covered', () {
    expect(expected.length, Network.values.length * ScriptType.values.length);
  });

  for (final entry in expected.entries) {
    final (network, scriptType) = entry.key;
    test('$network / $scriptType', () async {
      final xpub = switch (network.isBitcoin
          ? await secret.derive.xpub(
              network: network.bitcoin,
              scriptType: scriptType.shared,
            )
          : await secret.derive.liquidXpub(
              network: network.liquid,
              scriptType: scriptType.shared,
            )) {
        p.Ok(:final value) => value,
        p.Err(:final failure) => fail('xpub: ${failure.runtimeType}'),
      };

      expect(
        WalletMetadataService.encodeOrigin(
          fingerprint: secret.id.hex,
          network: network,
          scriptType: scriptType,
        ),
        entry.value.id,
      );
      expect(xpub, entry.value.xpub);
      expect(
        Bip32Derivation.getBip32Xpub(xpub).fingerprintHex,
        entry.value.xpubFingerprint,
      );
    });
  }
}
