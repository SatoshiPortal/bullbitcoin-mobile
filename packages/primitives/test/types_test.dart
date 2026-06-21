import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  group('Network', () {
    test('fromEnvironment maps the four combinations', () {
      expect(
        Network.fromEnvironment(isTestnet: false, isLiquid: false),
        Network.bitcoinMainnet,
      );
      expect(
        Network.fromEnvironment(isTestnet: true, isLiquid: false),
        Network.bitcoinTestnet,
      );
      expect(
        Network.fromEnvironment(isTestnet: false, isLiquid: true),
        Network.liquidMainnet,
      );
      expect(
        Network.fromEnvironment(isTestnet: true, isLiquid: true),
        Network.liquidTestnet,
      );
    });

    test('coin types match BIP44 registry', () {
      expect(Network.bitcoinMainnet.coinType, 0);
      expect(Network.liquidMainnet.coinType, 1776);
    });

    test('fromName parses known, throws ArgumentError on unknown', () {
      expect(Network.fromName('liquidTestnet'), Network.liquidTestnet);
      expect(() => Network.fromName('garbage'), throwsArgumentError);
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

  group('Network.tryFromName', () {
    test('parses known, returns null for unknown', () {
      expect(Network.tryFromName('bitcoinMainnet'), Network.bitcoinMainnet);
      expect(Network.tryFromName('garbage'), isNull);
    });
  });

  group('getXpubType', () {
    test('mainnet', () {
      expect(ScriptType.bip84.getXpubType(Network.bitcoinMainnet), XpubType.zpub);
      expect(ScriptType.bip49.getXpubType(Network.bitcoinMainnet), XpubType.ypub);
      expect(ScriptType.bip44.getXpubType(Network.bitcoinMainnet), XpubType.xpub);
    });

    test('testnet', () {
      expect(ScriptType.bip84.getXpubType(Network.bitcoinTestnet), XpubType.vpub);
      expect(ScriptType.bip49.getXpubType(Network.bitcoinTestnet), XpubType.upub);
      expect(ScriptType.bip44.getXpubType(Network.bitcoinTestnet), XpubType.tpub);
    });

    test('version bytes are 4 bytes', () {
      for (final t in XpubType.values) {
        expect(t.versionBytes, hasLength(4));
      }
    });
  });
}
