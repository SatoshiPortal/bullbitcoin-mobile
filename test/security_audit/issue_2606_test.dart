// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2606
// Finding: imported label text can exactly match a privileged system-label name.
// Regression test for the fix.

import 'package:bb_mobile/features/labels/domain/labels_import_exception.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_system.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2606 forged system label', () {
    test('reserved system label names are rejected on import', () {
      // The rejection is the security property and is unchanged. Only the
      // exception type moved: it was LabelValidationException, which is not a
      // LabelsImportException and so fell past the import use-case's typed
      // handler into the catch-all — the user was told "Oops something went
      // wrong" rather than which file was at fault. Asserting the problem
      // here pins both the rejection and the reason.
      expect(
        () => Bip329LabelsCodec().decode(
          '{"type":"tx","ref":"${'a' * 64}","label":"swaps"}',
        ),
        throwsA(
          isA<LabelsImportException>().having(
            (e) => e.problem,
            'problem',
            LabelsImportProblem.reservedName,
          ),
        ),
      );
    });

    test('every system label name is rejected, not just the one sampled '
        'above', () {
      for (final system in LabelSystem.values) {
        expect(
          () => Bip329LabelsCodec().decode(
            '{"type":"tx","ref":"${'a' * 64}","label":"${system.label}"}',
          ),
          throwsA(isA<LabelsImportException>()),
          reason: '${system.label} must not be importable as a user label',
        );
      }
    });
  });
}
