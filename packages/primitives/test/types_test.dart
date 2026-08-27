import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test('networks preserve chain-specific environments', () {
    expect(BitcoinNetwork.signet.env, NetworkEnv.signet);
    expect(LiquidNetwork.regtest.env, NetworkEnv.regtest);
    expect(
      LiquidNetwork.values.map((network) => network.env),
      isNot(contains(NetworkEnv.signet)),
    );
  });

  test('network parsers reject unknown input', () {
    expect(BitcoinNetwork.fromName('signet'), BitcoinNetwork.signet);
    expect(() => BitcoinNetwork.fromName('unknown'), throwsArgumentError);
    expect(LiquidNetwork.tryFromName('signet'), isNull);
  });

  test('script types map extended public key prefixes', () {
    expect(ScriptType.fromExtendedPublicKey('zpub...'), ScriptType.bip84);
    expect(ScriptType.fromExtendedPublicKey('upub...'), ScriptType.bip49);
    expect(
      () => ScriptType.fromExtendedPublicKey('qpub...'),
      throwsArgumentError,
    );
  });

  test('xpub version bytes stay pinned', () {
    expect(XpubType.xpub.versionBytes, [0x04, 0x88, 0xB2, 0x1E]);
    expect(XpubType.zpub.versionBytes, [0x04, 0xB2, 0x47, 0x46]);
    expect(XpubType.vpub.versionBytes, [0x04, 0x5F, 0x1C, 0xF6]);
  });

  test('script types choose network-specific xpub formats', () {
    expect(ScriptType.bip84.getXpubType(BitcoinNetwork.mainnet), XpubType.zpub);
    expect(ScriptType.bip84.getXpubType(BitcoinNetwork.signet), XpubType.vpub);
  });
}
