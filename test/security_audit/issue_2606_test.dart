// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2606
// Finding: imported label text can exactly match a privileged system-label name.
// Regression test for the fix.

import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2606 forged system label', () {
    test('a reserved system label name is never imported as a label', () {
      // The security property: a file cannot create a label carrying a
      // privileged system name. The file is no longer rejected as a whole
      // (the app exports its own markers, so its own export must import back):
      // the marker is skipped and the other labels still import.
      final decoded = Bip329LabelsCodec().decode(
        '{"type":"tx","ref":"${'a' * 64}","label":"swaps"}\n'
        '{"type":"tx","ref":"${'b' * 64}","label":"coffee"}',
      );
      expect(decoded.labels.map((l) => l.label), ['coffee']);
    });

    test('every system label name is skipped, not just the one sampled '
        'above', () {
      for (final system in LabelSystem.values) {
        final decoded = Bip329LabelsCodec().decode(
          '{"type":"tx","ref":"${'a' * 64}","label":"${system.label}"}',
        );
        expect(
          decoded.labels,
          isEmpty,
          reason: '${system.label} must not be importable as a user label',
        );
      }
    });
  });
}
