import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart';
import 'package:secrets/src/data/data.dart';
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// Fixed mnemonics in, fixed keys out — pinned as values, not as prefixes.
///
/// Everything here is pure Dart (bip39, bip32, bip85), so it runs without the FFI and fails the moment identity, xpub or BIP85 derivation changes shape. The integration suite asserts the same constants against the engines. Two of these identities are anchored independently: `73c5da0a` is the published BIP39 vector's master fingerprint, and `3f635a63` was computed by a second auditor (Codex, 2026-09-17) before being pinned here.
void main() {
  const zoo = [
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'zoo',
    'wrong',
  ];
  final abandon = List.filled(11, 'abandon') + ['about'];

  const vectors =
      <
        ({
          String label,
          String? passphrase,
          String id,
          String zpub,
          String vpub,
          String bip85At0,
          String bip85At1,
        })
      >[
        (
          label: 'zoo…wrong',
          passphrase: null,
          id: '3f635a63',
          zpub:
              'zpub6rD5AGSXPTDMSnpmczjENMT3NvVF7q5MySww6uxitUsBYgkZLeBywrcwUWhW5YkeY2aS7xc45APPgfA6s6wWfG2gnfABq6TDz9zqeMu2JCY',
          vpub:
              'vpub5YePEeNjBvnC6tZF84CnP5tFTVEGSA9tdCunoueAReLc7AfmynBGnQdcwUmfoyyFyucAXxTMc4S895n71NVC3VsaTWQbahtw6MH4iUD56xJ',
          bip85At0:
              'c8e13c54dfebea496b2f3bcde9d92fc548119ec977037ba200294b7be6ac83d3',
          bip85At1:
              '72d00dec7720de76b9ad403ab5c1a7be08966388027da18ec88f48396462689e',
        ),
        (
          label: 'zoo…wrong + TREZOR',
          passphrase: 'TREZOR',
          id: '128d6f17',
          zpub:
              'zpub6rrpm4MEve6GXeUtUxJ7EqaXJK9zmR7TjkecdsBgzgRM6SrvJRb639Yun2frf1sPPfG5MSWWSNGZxpEBr38eXFmfjJazrdCn2o87bwrhvQe',
          vpub:
              'vpub5YYQjS6iXKPWqegv4SUED2ZJZ686qyHVWg1fpi1P4KgLWWfi2fdVgYzfyhw1rikSJkCdPNMaSiBgYm578VfUXYmq8QhPinkKcSLZuLZKUrP',
          bip85At0:
              'ae19025b1524f3ef42b3b1768cb0924549544ea3b96750876b46b37494900465',
          bip85At1:
              'e6302b4e7ba1b90d5f22097e92c533b9c6d2d4cddf02cd71919fbaa5ea41eab3',
        ),
        (
          label: 'abandon…about',
          passphrase: null,
          id: '73c5da0a',
          zpub:
              'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1ADqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
          vpub:
              'vpub5Y6cjg78GGuNLsaPhmYsiw4gYX3HoQiRBiSwDaBXKUafCt9bNwWQiitDk5VZ5BVxYnQdwoTyXSs2JHRPAgjAvtbBrf8ZhDYe2jWAqvZVnsc',
          bip85At0:
              'e477d4694160a384b28ee2f72b54edcf0822fd6e1ee1780447455cdbed8f8c45',
          bip85At1:
              '1cbcb9200cc786c83bc6307b112d113fb1f8426ca52aa1acdad4bb8b29a52169',
        ),
      ];

  for (final v in vectors) {
    test(v.label, () async {
      FakeSecureStoragePlatform().install();
      final repo = SecretRepository();
      final words = v.label.startsWith('zoo') ? zoo : abandon;

      final info = ok(await repo.store(words: words, passphrase: v.passphrase));
      expect(info.id.hex, v.id);

      final material = ok(await repo.use(info, (m) => m));
      String xpub(BitcoinNetwork n) => Deriver.bitcoin.xpub(
        material,
        scriptType: ScriptType.bip84,
        coinType: n.coinType,
        xpubType: ScriptType.bip84.getXpubType(n),
      );
      expect(xpub(BitcoinNetwork.mainnet), v.zpub);
      expect(xpub(BitcoinNetwork.testnet), v.vpub);
      expect(Deriver.bip85.hex(material, numBytes: 32, index: 0), v.bip85At0);
      expect(Deriver.bip85.hex(material, numBytes: 32, index: 1), v.bip85At1);
    });
  }
}
