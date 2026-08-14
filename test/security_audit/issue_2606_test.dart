// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2606
// Finding: imported label text can exactly match a privileged system-label name.
// Regression test for the fix.

import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2606 forged system label', () {
    test('reserved system label names are rejected on import', () {
      expect(
        () => Bip329LabelsCodec().decode(
          '{"type":"tx","ref":"${'a' * 64}","label":"swaps"}',
        ),
        throwsA(isA<LabelValidationException>()),
      );
    });
  });
}
