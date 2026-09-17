import 'package:bip85_entropy/bip85_entropy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/crypto/crypto.dart' show Backup;
import 'package:secrets/src/crypto/derivers/derivers.dart' show Deriver;
import 'package:secrets/src/data/secret_repository.dart' show SecretRepository;
import 'package:secrets/src/domain/secret_material.dart' show SecretMaterial;

import 'fake_secure_storage_platform.dart';
import 'result_helpers.dart';

/// Pinned outputs for a known seed.
///
/// Every value here is already in users' hands, one way or another: a
/// backup key that changes makes existing vaults unopenable, an xpub
/// that changes points a wallet at different addresses. A round-trip
/// test cannot see any of it — both directions drift together and stay
/// green. These constants are what notice.
void main() {
  // The published BIP39 test mnemonic.
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

  const masterXprvMainnet =
      'xprv9s21ZrQH143K3GJpoapnV8SFfukcVBSfeCficPSGfubmSFDxo1kuHnLisriDv'
      'SnRRuL2Qrg5ggqHKNVpxR86QEC8w35uxmGoggxtQTPvfUu';
  const masterXprvTestnet =
      'tprv8ZgxMBicQKsPe5YMU9gHen4Ez3ApihUfykaqUorj9t6FDqy3nP6eoXiAo2ssv'
      'pAjoLroQxHqr3R5nE3a5dU3DHTjTgJDd7zrbniJr6nrCzd';

  late SecretMaterial secret;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    final repo = SecretRepository();
    final info = ok(await repo.store(words: words));
    expect(info.id, Fingerprint('73c5da0a'));
    secret = ok(await repo.use(info, (m) => m));
  });

  group('master xprv', () {
    test('mainnet', () {
      expect(
        Deriver.bitcoin.masterXprv(secret, BitcoinNetwork.mainnet),
        masterXprvMainnet,
      );
    });

    test('the test environments share testnet version bytes', () {
      // BIP32 defines two sets, not four: a tprv on signet is correct,
      // not an approximation. If this ever splits, it splits here.
      for (final network in [
        BitcoinNetwork.testnet,
        BitcoinNetwork.signet,
        BitcoinNetwork.regtest,
      ]) {
        expect(
          Deriver.bitcoin.masterXprv(secret, network),
          masterXprvTestnet,
          reason: 'network: ${network.name}',
        );
      }
    });
  });

  group('RecoverBull backup key', () {
    // The one that matters most: a vault sealed under a key this
    // function no longer produces is a vault nobody can open.

    test('is pinned for a known path', () {
      expect(
        Backup.recoverbull.backupKey(
          masterXprv: masterXprvMainnet,
          path: "1608'/0'/0'",
        ),
        '2f8551b0e5f0cfc4c4d128a32d028ce512d06acdda4f80f8e7de0e7b3e0a9111',
      );
    });

    test('tolerates the historical m/ prefix', () {
      // rust-bip85 emitted one before the fork, so paths of both shapes
      // exist in the wild and must derive the same key.
      expect(
        Backup.recoverbull.backupKey(
          masterXprv: masterXprvMainnet,
          path: "m/1608'/0'/0'",
        ),
        Backup.recoverbull.backupKey(
          masterXprv: masterXprvMainnet,
          path: "1608'/0'/0'",
        ),
      );
    });

    test('a different index gives a different key', () {
      expect(
        Backup.recoverbull.backupKey(
          masterXprv: masterXprvMainnet,
          path: "1608'/0'/7'",
        ),
        '8ab9b00dad96540c8728260db5aa3ecaf7172566800d11aaca1852bfa018a574',
      );
    });
  });

  test('account xpub is pinned', () {
    expect(
      Deriver.bitcoin.xpub(
        secret,
        scriptType: ScriptType.bip84,
        coinType: 0,
        xpubType: XpubType.zpub,
      ),
      'zpub6rFR7y4Q2AijBEqTUquhVz398htDFrtymD9xYYfG1m4wAcvPhXNfE3EfH1r1A'
      'DqtfSdVCToUG868RvUUkgDKf31mGDtKsAYz2oz2AGutZYs',
    );
  });

  group('BIP85', () {
    test('hex entropy is pinned', () {
      expect(
        Deriver.bip85.hex(secret, numBytes: 32, index: 0),
        'e477d4694160a384b28ee2f72b54edcf0822fd6e1ee1780447455cdbed8f8c45',
      );
    });

    test('derives from the mainnet encoding, whatever the wallet chain', () {
      // BIP85 entropy is an HMAC over the derived private key; version
      // bytes never enter it, so there is one root per seed.
      expect(Deriver.bip85.root(secret), masterXprvMainnet);
    });

    test('the library refuses a tprv — which is why the root is fixed', () {
      // Not our code, but the reason for it. The app used to hand
      // bip85_entropy the wallet's network-encoded xprv, so BIP85 and
      // the RecoverBull backup key failed on every non-mainnet wallet.
      // If the library ever accepts a tprv this can go; the derivation
      // above must not change with it.
      expect(
        () => Bip85Entropy.deriveHex(
          xprvBase58: masterXprvTestnet,
          numBytes: 32,
          index: 0,
        ),
        throwsA(isA<Bip85Exception>()),
      );
      expect(
        () => Backup.recoverbull.backupKey(
          masterXprv: masterXprvTestnet,
          path: "1608'/0'/0'",
        ),
        throwsA(isA<Bip85Exception>()),
      );
    });
  });
}
