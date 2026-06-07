import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/trezor/frameworks/trezor_connect_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('inputScriptTypeFor', () {
    test('BIP84 → SPENDWITNESS', () {
      expect(inputScriptTypeFor(ScriptType.bip84), 'SPENDWITNESS');
    });
    test('BIP49 → SPENDP2SHWITNESS', () {
      expect(inputScriptTypeFor(ScriptType.bip49), 'SPENDP2SHWITNESS');
    });
    test('BIP44 → SPENDADDRESS', () {
      expect(inputScriptTypeFor(ScriptType.bip44), 'SPENDADDRESS');
    });
  });

  group('changeOutputScriptTypeFor', () {
    test('BIP84 → PAYTOWITNESS', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip84), 'PAYTOWITNESS');
    });
    test('BIP49 → PAYTOP2SHWITNESS', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip49), 'PAYTOP2SHWITNESS');
    });
    test('BIP44 → PAYTOADDRESS', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip44), 'PAYTOADDRESS');
    });
  });

  group('trezorCoinLabelFor', () {
    test('mainnet → btc', () {
      expect(trezorCoinLabelFor(isTestnet: false), 'btc');
    });
    test('testnet → test', () {
      expect(trezorCoinLabelFor(isTestnet: true), 'test');
    });
  });
}
