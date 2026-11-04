import 'package:flutter_test/flutter_test.dart';
import 'package:wallet/wallet.dart';

void main() {
  const fingerprints = ['deadbeef', 'A1B2C3D4'];
  for (final fingerprint in fingerprints) {
    for (final network in Network.values) {
      for (final script in ScriptType.values) {
        test('preserves $fingerprint ${network.name} ${script.name}', () {
          final coin = network.isTestnet
              ? '1h'
              : network.isBitcoin
              ? '0h'
              : '1776h';
          final path = '[$fingerprint/${script.purpose}h/$coin/0h]';
          final prefix = network.isBitcoin ? '' : 'el';
          final expected = switch (script) {
            ScriptType.bip44 => '${prefix}pkh($path)',
            ScriptType.bip49 => '${prefix}sh(wpkh($path))',
            ScriptType.bip84 => '${prefix}wpkh($path)',
          };
          final encoded = WalletOriginCodec.encodeOrigin(
            fingerprint: fingerprint,
            network: network,
            scriptType: script,
          );
          expect(encoded, expected);
          expect(WalletOriginCodec.decodeOrigin(origin: encoded), (
            fingerprint: fingerprint,
            network: network,
            script: script,
            account: '0h',
          ));
        });
      }
    }
  }

  test('preserves the unanchored legacy parser and account text', () {
    expect(
      WalletOriginCodec.decodeOrigin(
        origin: 'prefix wpkh([deadbeef/84h/0h/007h]) suffix',
      ),
      (
        fingerprint: 'deadbeef',
        network: Network.bitcoinMainnet,
        script: ScriptType.bip84,
        account: '007h',
      ),
    );
  });

  for (final origin in [
    '',
    'wpkh([xyz/84h/0h/0h])',
    "[deadbeef/84'/0'/0']",
    '[deadbeef/84h/0h]',
  ]) {
    test('preserves malformed-origin failure: $origin', () {
      expect(
        () => WalletOriginCodec.decodeOrigin(origin: origin),
        throwsA('Invalid origin format: $origin'),
      );
    });
  }
  test('preserves unsupported script failure', () {
    expect(
      () => WalletOriginCodec.decodeOrigin(origin: '[deadbeef/86h/0h/0h]'),
      throwsA('Unknown script: 86h'),
    );
  });
  test('preserves unsupported network failure', () {
    expect(
      () => WalletOriginCodec.decodeOrigin(origin: '[deadbeef/84h/2h/0h]'),
      throwsA('Unknown script: 2h'),
    );
  });
}
