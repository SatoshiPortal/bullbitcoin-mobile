import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:test/test.dart';

/// Property-based tests for BIP32 derivation path logic.
///
/// IMPORTANT: These tests verify enum properties and mappings, NOT the
/// cryptographic derivation (which requires FFI). The distinction is
/// documented per test.
///
/// Known accepted risks (from retroactive audit):
/// - Path format tests removed: they were tautological (constructing strings
///   and asserting string properties, never calling production code)
/// - Account index tests removed: same tautology
///
/// Target: lib/core/utils/bip32_derivation.dart
void main() {
  group('purpose codes match BIP standards', () {
    // Bug: wrong purpose code → wrong derivation path → wrong addresses → fund loss
    // These are spec constants, not computed values
    test('BIP44 purpose = 44', () {
      expect(ScriptType.bip44.purpose, equals(44));
    });

    test('BIP49 purpose = 49', () {
      expect(ScriptType.bip49.purpose, equals(49));
    });

    test('BIP84 purpose = 84', () {
      expect(ScriptType.bip84.purpose, equals(84));
    });
  });

  group('coin types match SLIP-44 standard', () {
    // Bug: wrong coin type → derive keys for wrong chain → fund loss
    test('Bitcoin mainnet = 0', () {
      expect(Network.bitcoinMainnet.coinType, equals(0));
    });

    test('Bitcoin testnet = 1', () {
      expect(Network.bitcoinTestnet.coinType, equals(1));
    });

    test('Liquid mainnet = 1776', () {
      expect(Network.liquidMainnet.coinType, equals(1776));
    });

    test('Liquid testnet = 1 (same as Bitcoin testnet — documented collision)', () {
      // This is a known SLIP-44 registration gap. Liquid testnet has no
      // registered coin type. The wallet distinguishes via network object,
      // not coin type alone. See project_upstream_findings.md.
      expect(Network.liquidTestnet.coinType, equals(1));
    });
  });

  group('XpubType mapping — mainnet', () {
    // Bug: wrong XpubType → wrong version bytes → incompatible xpub format
    test('BIP44 mainnet → xpub', () {
      expect(ScriptType.bip44.getXpubType(Network.bitcoinMainnet),
          equals(XpubType.xpub));
    });

    test('BIP49 mainnet → ypub', () {
      expect(ScriptType.bip49.getXpubType(Network.bitcoinMainnet),
          equals(XpubType.ypub));
    });

    test('BIP84 mainnet → zpub', () {
      expect(ScriptType.bip84.getXpubType(Network.bitcoinMainnet),
          equals(XpubType.zpub));
    });
  });

  group('XpubType mapping — testnet', () {
    test('BIP44 testnet → tpub', () {
      expect(ScriptType.bip44.getXpubType(Network.bitcoinTestnet),
          equals(XpubType.tpub));
    });

    test('BIP49 testnet → upub', () {
      expect(ScriptType.bip49.getXpubType(Network.bitcoinTestnet),
          equals(XpubType.upub));
    });

    test('BIP84 testnet → vpub', () {
      expect(ScriptType.bip84.getXpubType(Network.bitcoinTestnet),
          equals(XpubType.vpub));
    });
  });

  group('XpubType version bytes — SLIP-132 standard values', () {
    // Bug: wrong version bytes → xpub rejected by other wallets or decoded wrong
    // Values from: https://github.com/satoshilabs/slips/blob/master/slip-0132.md
    test('xpub version bytes = [0x04, 0x88, 0xB2, 0x1E]', () {
      expect(XpubType.xpub.versionBytes, equals([0x04, 0x88, 0xB2, 0x1E]));
    });

    test('ypub version bytes = [0x04, 0x9D, 0x7C, 0xB2]', () {
      expect(XpubType.ypub.versionBytes, equals([0x04, 0x9D, 0x7C, 0xB2]));
    });

    test('zpub version bytes = [0x04, 0xB2, 0x47, 0x46]', () {
      expect(XpubType.zpub.versionBytes, equals([0x04, 0xB2, 0x47, 0x46]));
    });

    test('tpub version bytes = [0x04, 0x35, 0x87, 0xCF]', () {
      expect(XpubType.tpub.versionBytes, equals([0x04, 0x35, 0x87, 0xCF]));
    });

    test('upub version bytes = [0x04, 0x4A, 0x52, 0x62]', () {
      expect(XpubType.upub.versionBytes, equals([0x04, 0x4A, 0x52, 0x62]));
    });

    test('vpub version bytes = [0x04, 0x5F, 0x1C, 0xF6]', () {
      expect(XpubType.vpub.versionBytes, equals([0x04, 0x5F, 0x1C, 0xF6]));
    });

    test('all version bytes are exactly 4 bytes', () {
      for (final xpubType in XpubType.values) {
        expect(xpubType.versionBytes.length, equals(4),
            reason: '${xpubType.name} should have 4 version bytes');
      }
    });

    test('all version bytes are unique', () {
      final seen = <String>{};
      for (final xpubType in XpubType.values) {
        final key = xpubType.versionBytes.toString();
        expect(seen.contains(key), isFalse,
            reason: '${xpubType.name} has duplicate version bytes');
        seen.add(key);
      }
    });
  });
}
