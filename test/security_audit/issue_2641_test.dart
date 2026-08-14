// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2641
// Finding: imported labels bypass NoteValidator content constraints.
// Regression test for the fix.

import 'dart:convert';

import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2641 imported label constraints', () {
    test('codec sanitizes oversized labels and control characters', () {
      final label = 'x' * 51 + '\n';
      final decoded = Bip329LabelsCodec().decode(
        jsonEncode({'type': 'tx', 'ref': 'a' * 64, 'label': label}),
      );

      final stored = LabelEntity(
        id: 1,
        type: decoded.labels.single.type,
        reference: decoded.labels.single.reference,
        label: decoded.labels.single.label,
      );
      expect(stored.label, 'x' * 50);
    });
  });
}
