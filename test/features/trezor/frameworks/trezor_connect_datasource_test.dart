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

  group('changeOutputScriptTypeFor (regression: review #3 BIP49)', () {
    test('BIP84 → PAYTOWITNESS', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip84), 'PAYTOWITNESS');
    });
    test('BIP49 → PAYTOP2SHWITNESS (the fix from review #3)', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip49), 'PAYTOP2SHWITNESS');
    });
    test('BIP44 → PAYTOADDRESS', () {
      expect(changeOutputScriptTypeFor(ScriptType.bip44), 'PAYTOADDRESS');
    });
  });

  group('detectOutputScriptType (byte detection for external outputs)', () {
    test('P2WPKH (00 14 <20 bytes>) → PAYTOWITNESS', () {
      final bytes = [0x00, 0x14, ...List.filled(20, 0)];
      expect(detectOutputScriptType(bytes), 'PAYTOWITNESS');
    });

    test('P2WSH (00 20 <32 bytes>) → PAYTOWITNESS', () {
      final bytes = [0x00, 0x20, ...List.filled(32, 0)];
      expect(detectOutputScriptType(bytes), 'PAYTOWITNESS');
    });

    test('P2PKH (76 a9 14 <20 bytes> 88 ac) → PAYTOADDRESS', () {
      final bytes = [0x76, 0xa9, 0x14, ...List.filled(20, 0), 0x88, 0xac];
      expect(detectOutputScriptType(bytes), 'PAYTOADDRESS');
    });

    test('P2SH (a9 14 <20 bytes> 87) → PAYTOSCRIPTHASH', () {
      final bytes = [0xa9, 0x14, ...List.filled(20, 0), 0x87];
      expect(detectOutputScriptType(bytes), 'PAYTOSCRIPTHASH');
    });

    test('P2TR (51 20 <32 bytes>) → PAYTOTAPROOT', () {
      final bytes = [0x51, 0x20, ...List.filled(32, 0)];
      expect(detectOutputScriptType(bytes), 'PAYTOTAPROOT');
    });

    test('unrecognized pattern → PAYTOWITNESS (BIP84 default)', () {
      final bytes = [0x00]; // too short, doesn't match any pattern
      expect(detectOutputScriptType(bytes), 'PAYTOWITNESS');
    });
  });
}
