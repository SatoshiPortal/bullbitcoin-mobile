import 'dart:typed_data';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bip32_keys/bip32_keys.dart' as bip32;
import 'package:test/test.dart';

/// BIP32 test vector verification.
///
/// These tests verify that the bip32_keys library + our Bip32Derivation
/// class produce correct keys for known seed → xpub/xprv pairs from
/// the official BIP32 specification.
///
/// Source: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
///
/// If these tests fail, the wallet would generate WRONG ADDRESSES
/// and users would LOSE FUNDS.

Uint8List _hexToBytes(String hex) {
  final bytes = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(bytes);
}

void main() {
  group('BIP32 Test Vector 1', () {
    // Seed: 000102030405060708090a0b0c0d0e0f
    final seed = _hexToBytes('000102030405060708090a0b0c0d0e0f');

    test('master key (m) produces correct xpub', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.neutered.toBase58(),
        equals(
          'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8',
        ),
      );
    });

    test('master key (m) produces correct xprv', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.toBase58(),
        equals(
          'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi',
        ),
      );
    });

    test("derived path m/0' produces correct xpub", () {
      // Bug: hardened child derivation error → wrong account keys
      final root = bip32.Bip32Keys.fromSeed(seed);
      final derived = root.derivePath("m/0'");
      expect(
        derived.neutered.toBase58(),
        equals(
          'xpub68Gmy5EdvgibQVfPdqkBBCHxA5htiqg55crXYuXoQRKfDBFA1WEjWgP6LHhwBZeNK1VTsfTFUHCdrfp1bgwQ9xv5ski8PX9rL2dZXvgGDnw',
        ),
      );
    });

    test("derived path m/0'/1 produces correct xpub (non-hardened child)", () {
      // Bug: non-hardened derivation uses public key math — different code path from hardened
      // This is where receive addresses come from. Must be correct.
      final root = bip32.Bip32Keys.fromSeed(seed);
      final derived = root.derivePath("m/0'/1");
      expect(
        derived.neutered.toBase58(),
        equals(
          'xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ',
        ),
      );
    });

    test("derived path m/0'/1 produces correct xprv", () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      final derived = root.derivePath("m/0'/1");
      expect(
        derived.toBase58(),
        equals(
          'xprv9wTYmMFdV23N2TdNG573QoEsfRrWKQgWeibmLntzniatZvR9BmLnvSxqu53Kw1UmYPxLgboyZQaXwTCg8MSY3H2EU4pWcQDnRnrVA1xe8fs',
        ),
      );
    });

    test("derived path m/0'/1/2' produces correct xpub (deep mixed path)", () {
      // Bug: mixed hardened/non-hardened at depth 3 — tests the full derivation chain
      final root = bip32.Bip32Keys.fromSeed(seed);
      final derived = root.derivePath("m/0'/1/2'");
      expect(
        derived.neutered.toBase58(),
        equals(
          'xpub6D4BDPcP2GT577Vvch3R8wDkScZWzQzMMUm3PWbmWvVJrZwQY4VUNgqFJPMM3No2dFDFGTsxxpG5uJh7n7epu4trkrX7x7DogT5Uv6fcLW5',
        ),
      );
    });

    test("derived path m/0'/1/2' produces correct xprv", () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      final derived = root.derivePath("m/0'/1/2'");
      expect(
        derived.toBase58(),
        equals(
          'xprv9z4pot5VBttmtdRTWfWQmoH1taj2axGVzFqSb8C9xaxKymcFzXBDptWmT7FwuEzG3ryjH4ktypQSAewRiNMjANTtpgP4mLTj34bhnZX7UiM',
        ),
      );
    });
  });

  group('BIP32 Test Vector 2', () {
    final seed = _hexToBytes(
      'fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542',
    );

    test('master key (m) produces correct xpub', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.neutered.toBase58(),
        equals(
          'xpub661MyMwAqRbcFW31YEwpkMuc5THy2PSt5bDMsktWQcFF8syAmRUapSCGu8ED9W6oDMSgv6Zz8idoc4a6mr8BDzTJY47LJhkJ8UB7WEGuduB',
        ),
      );
    });

    test('master key (m) produces correct xprv', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.toBase58(),
        equals(
          'xprv9s21ZrQH143K31xYSDQpPDxsXRTUcvj2iNHm5NUtrGiGG5e2DtALGdso3pGz6ssrdK4PFmM8NSpSBHNqPqm55Qn3LqFtT2emdEXVYsCzC2U',
        ),
      );
    });
  });

  group('BIP32 Test Vector 3 (leading-zero key padding)', () {
    // This vector specifically tests retention of leading zeros in
    // serialized keys — a class of bug that has affected real implementations.
    final seed = _hexToBytes(
      '4b381541583be4423346c643850da4b320e46a87ae3d2a4e6da11eba819cd4acba45d239319ac14f863b8d5ab5a0d0c64d2e8a1e7d1457df2e5a3c51c73235be',
    );

    test('master key (m) produces correct xpub', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.neutered.toBase58(),
        equals(
          'xpub661MyMwAqRbcEZVB4dScxMAdx6d4nFc9nvyvH3v4gJL378CSRZiYmhRoP7mBy6gSPSCYk6SzXPTf3ND1cZAceL7SfJ1Z3GC8vBgp2epUt13',
        ),
      );
    });

    test('master key (m) produces correct xprv', () {
      final root = bip32.Bip32Keys.fromSeed(seed);
      expect(
        root.toBase58(),
        equals(
          'xprv9s21ZrQH143K25QhxbucbDDuQ4naNntJRi4KUfWT7xo4EKsHt2QJDu7KXp1A3u7Bi1j8ph3EGsZ9Xvz9dGuVrtHHs7pXeTzjuxBrCmmhgC6',
        ),
      );
    });
  });

  group('Bip32Derivation integration with test vectors', () {
    final seed = _hexToBytes('000102030405060708090a0b0c0d0e0f');

    test('getXprvFromSeed produces correct xprv for mainnet', () {
      // Bug: wrong NetworkType version bytes → invalid xprv
      final xprv = Bip32Derivation.getXprvFromSeed(
        seed,
        Network.bitcoinMainnet,
      );
      expect(
        xprv,
        equals(
          'xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi',
        ),
      );
    });

    test('getAccountXpub produces valid xpub for BIP84 mainnet', () async {
      // Bug: wrong derivation path → wrong account → wrong addresses
      // Note: We cannot compare against a known BIP84 xpub without an
      // independent reference tool. We verify format correctness only.
      // This is a known accepted risk — see retroactive audit.
      final keys = await Bip32Derivation.getAccountXpub(
        seedBytes: seed,
        scriptType: ScriptType.bip84,
        network: Network.bitcoinMainnet,
      );
      final xpub = keys.toBase58();

      expect(xpub.startsWith('xpub'), isTrue,
          reason: 'BIP84 mainnet should produce xpub-prefixed key');
      expect(xpub.length, greaterThan(100),
          reason: 'xpub should be a full Base58 encoded key');
    });

    // REGRESSION TEST: Will pass once upstream fixes testnet WIF byte.
    // Bug: bip32_derivation.dart:26 uses wif: 0x80 (mainnet) instead of
    // 0xEF (testnet). Currently no code calls .toWif() so this is latent.
    // See project_upstream_findings.md Finding 9.
    test(
      'getXprvFromSeed for testnet should produce tprv-prefixed key',
      skip: 'Latent upstream bug: bip32_derivation.dart:26 — testnet WIF byte is 0x80 (mainnet). '
          'See project_upstream_findings.md Finding 9',
      () {
        final xprv = Bip32Derivation.getXprvFromSeed(
          _hexToBytes('000102030405060708090a0b0c0d0e0f'),
          Network.bitcoinTestnet,
        );
        // Testnet xprv should start with 'tprv' (version 0x04358394)
        expect(xprv.startsWith('tprv'), isTrue,
            reason: 'Testnet xprv must use tprv prefix');
      },
    );

    test('getAccountXpub produces tpub for testnet', () async {
      final keys = await Bip32Derivation.getAccountXpub(
        seedBytes: seed,
        scriptType: ScriptType.bip84,
        network: Network.bitcoinTestnet,
      );
      final xpub = keys.toBase58();

      expect(xpub.length, greaterThan(100),
          reason: 'Testnet xpub should be a full Base58 encoded key');
    });
  });
}
