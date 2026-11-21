import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/cbor.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signers/signers.dart';

void main() {
  test(
    'mixed account ignores unsupported scripts before descriptor parsing',
    () {
      CryptoHdKey key(int purpose) => CryptoHdKey(
        keyData: hex.decode(
          '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798',
        ),
        chainCode: List.filled(32, 1),
        network: HdKeyNetwork.mainnet,
        keypath: [Index(purpose, true), Index(0, true), Index(0, true)],
      );
      final account = CryptoAccount.fromCbor(
        Uint8List.fromList(
          cbor.encode(
            CborMap({
              const CborSmallInt(1): const CborSmallInt(0x12345678),
              const CborSmallInt(2): CborList([]),
            }),
          ),
        ),
      )..hdKeys = [key(86), key(84)];
      final descriptors =
          jsonDecode(account.toString()) as Map<String, dynamic>;
      expect(descriptors.keys, ['bip84']);
      expect(descriptors['bip84'], startsWith('wpkh([12345678/84h/0h/0h]'));
    },
  );
}
