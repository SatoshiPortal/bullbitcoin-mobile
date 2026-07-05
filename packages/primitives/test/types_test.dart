import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Network', () {
    test('chain is the type; env is orthogonal', () {
      expect(BitcoinNetwork.signet.env, NetworkEnv.signet);
      expect(LiquidNetwork.regtest.env, NetworkEnv.regtest);
      // Liquid has no signet — there is simply no such value.
      expect(LiquidNetwork.values.map((n) => n.env),
          isNot(contains(NetworkEnv.signet)));
      expect(BitcoinNetwork.values.map((n) => n.env), contains(NetworkEnv.signet));
    });

    test('isMainnet only for mainnet (testnet/signet/regtest are not)', () {
      expect(BitcoinNetwork.mainnet.isMainnet, isTrue);
      expect(BitcoinNetwork.testnet.isMainnet, isFalse);
      expect(BitcoinNetwork.signet.isMainnet, isFalse);
      expect(BitcoinNetwork.regtest.isMainnet, isFalse);
      expect(LiquidNetwork.mainnet.isMainnet, isTrue);
    });

    test('coin types match SLIP-44 (testnet/signet/regtest all = 1)', () {
      expect(BitcoinNetwork.mainnet.coinType, 0);
      expect(BitcoinNetwork.testnet.coinType, 1);
      expect(BitcoinNetwork.signet.coinType, 1);
      expect(BitcoinNetwork.regtest.coinType, 1);
      expect(LiquidNetwork.mainnet.coinType, 1776);
      expect(LiquidNetwork.testnet.coinType, 1);
    });

    test('fromName / tryFromName per chain', () {
      expect(BitcoinNetwork.fromName('signet'), BitcoinNetwork.signet);
      expect(() => BitcoinNetwork.fromName('garbage'), throwsArgumentError);
      expect(BitcoinNetwork.tryFromName('mainnet'), BitcoinNetwork.mainnet);
      expect(BitcoinNetwork.tryFromName('garbage'), isNull);
      expect(LiquidNetwork.fromName('regtest'), LiquidNetwork.regtest);
      expect(LiquidNetwork.tryFromName('signet'), isNull); // Liquid has none
    });
  });

  group('ScriptType', () {
    test('purposes', () {
      expect(ScriptType.bip84.purpose, 84);
      expect(ScriptType.bip49.purpose, 49);
      expect(ScriptType.bip44.purpose, 44);
    });

    test('fromExtendedPublicKey (mainnet + testnet prefixes)', () {
      expect(ScriptType.fromExtendedPublicKey('zpub...'), ScriptType.bip84);
      expect(ScriptType.fromExtendedPublicKey('ypub...'), ScriptType.bip49);
      expect(ScriptType.fromExtendedPublicKey('xpub...'), ScriptType.bip44);
      expect(ScriptType.fromExtendedPublicKey('vpub...'), ScriptType.bip84);
      expect(ScriptType.fromExtendedPublicKey('upub...'), ScriptType.bip49);
      expect(ScriptType.fromExtendedPublicKey('tpub...'), ScriptType.bip44);
    });

    test('fromExtendedPublicKey rejects short / unknown input (ArgumentError)',
        () {
      expect(() => ScriptType.fromExtendedPublicKey('ab'), throwsArgumentError);
      expect(() => ScriptType.fromExtendedPublicKey('qpub..'),
          throwsArgumentError);
    });

    test('tryFromName is non-throwing', () {
      expect(ScriptType.tryFromName('bip84'), ScriptType.bip84);
      expect(ScriptType.tryFromName('nope'), isNull);
    });

    test('fromName parses known, throws ArgumentError on unknown', () {
      expect(ScriptType.fromName('bip49'), ScriptType.bip49);
      expect(() => ScriptType.fromName('nope'), throwsArgumentError);
    });
  });

  group('getXpubType', () {
    test('mainnet', () {
      expect(ScriptType.bip84.getXpubType(BitcoinNetwork.mainnet), XpubType.zpub);
      expect(ScriptType.bip49.getXpubType(BitcoinNetwork.mainnet), XpubType.ypub);
      expect(ScriptType.bip44.getXpubType(BitcoinNetwork.mainnet), XpubType.xpub);
    });

    test('non-mainnet (testnet/signet/regtest) → testnet version bytes', () {
      for (final n in [
        BitcoinNetwork.testnet,
        BitcoinNetwork.signet,
        BitcoinNetwork.regtest,
      ]) {
        expect(ScriptType.bip84.getXpubType(n), XpubType.vpub);
        expect(ScriptType.bip49.getXpubType(n), XpubType.upub);
        expect(ScriptType.bip44.getXpubType(n), XpubType.tpub);
      }
    });

    test('version bytes are 4 bytes', () {
      for (final t in XpubType.values) {
        expect(t.versionBytes, hasLength(4));
      }
    });

    test('version bytes pin exact constants (no transposition)', () {
      // These feed real base58 xpub re-encoding; a transposed byte must fail.
      expect(XpubType.xpub.versionBytes, [0x04, 0x88, 0xB2, 0x1E]);
      expect(XpubType.ypub.versionBytes, [0x04, 0x9D, 0x7C, 0xB2]);
      expect(XpubType.zpub.versionBytes, [0x04, 0xB2, 0x47, 0x46]);
      expect(XpubType.tpub.versionBytes, [0x04, 0x35, 0x87, 0xCF]);
      expect(XpubType.upub.versionBytes, [0x04, 0x4A, 0x52, 0x62]);
      expect(XpubType.vpub.versionBytes, [0x04, 0x5F, 0x1C, 0xF6]);
    });
  });
}
