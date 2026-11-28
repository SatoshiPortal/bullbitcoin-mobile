import 'package:bull_recoverbull/src/data/passkey_availability.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('Mainnet build flag is parsed as explicitly configured', () {
    const configured = bool.fromEnvironment(
      'RECOVERBULL_PASSKEY_DEBUG_MAINNET',
    );
    const expected = bool.fromEnvironment('EXPECT_PASSKEY_DEBUG_MAINNET');
    expect(configured, expected);
  });

  bool available({
    bool debug = true,
    bool android = true,
    bool web = false,
    String rpId = 'passkey-demo.ethicnology.com',
    BitcoinNetwork? network = BitcoinNetwork.regtest,
    bool mainnetOptIn = false,
  }) => passkeysAvailableForBuild(
    debug: debug,
    android: android,
    web: web,
    rpId: rpId,
    network: network,
    mainnetOptIn: mainnetOptIn,
  );

  test('Regtest remains available with or without Mainnet opt-in', () {
    expect(available(), isTrue);
    expect(available(mainnetOptIn: true), isTrue);
  });

  test('Mainnet requires explicit opt-in', () {
    expect(available(network: BitcoinNetwork.mainnet), isFalse);
    expect(
      available(network: BitcoinNetwork.mainnet, mainnetOptIn: true),
      isTrue,
    );
  });

  test('other and unavailable networks are refused even with opt-in', () {
    expect(
      available(network: BitcoinNetwork.testnet, mainnetOptIn: true),
      isFalse,
    );
    expect(
      available(network: BitcoinNetwork.signet, mainnetOptIn: true),
      isFalse,
    );
    expect(available(network: null, mainnetOptIn: true), isFalse);
  });

  test('release, web, non-Android and missing RP are always refused', () {
    for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.regtest]) {
      expect(
        available(debug: false, network: network, mainnetOptIn: true),
        isFalse,
      );
      expect(
        available(web: true, network: network, mainnetOptIn: true),
        isFalse,
      );
      expect(
        available(android: false, network: network, mainnetOptIn: true),
        isFalse,
      );
      expect(
        available(rpId: '', network: network, mainnetOptIn: true),
        isFalse,
      );
    }
  });
}
