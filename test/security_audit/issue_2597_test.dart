// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2597
// Finding: xpub records accept and re-export extended private keys.
// Regression test for the fix.

import 'dart:typed_data';

import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bs58check/bs58check.dart' as base58;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2597 xprv accepted as xpub', () {
    test('private extended key is rejected for an xpub label', () {
      final payload = Uint8List(78);
      payload.buffer.asByteData().setUint32(0, 0x0488ade4);
      final xprv = base58.encode(payload);
      expect(
        () => LabelEntity(
          id: 1,
          type: LabelType.extendedPublicKey,
          reference: xprv,
          label: 'imported',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });
  });
}
