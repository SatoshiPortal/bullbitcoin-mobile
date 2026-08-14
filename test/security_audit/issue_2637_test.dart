// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2637
// Finding: a failed UR decode updates the error UI but never resets the reader.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2637 UR scanner recovery', () {
    test('scanner catch path has no reader reset', () {
      final source = File(
        'lib/core/widgets/qr_scanner_widget.dart',
      ).readAsStringSync();
      final catchStart = source.indexOf('} catch (e) {');
      final catchBody = source.substring(catchStart);

      expect(catchStart, isNonNegative);
      expect(catchBody, contains('_urReader.reset()'));
      expect(catchBody, contains("'UR processing failed'"));
    });

    test('reader exposes reset but widget never calls it', () {
      final readerSource = File('lib/core/urqr/urqr.dart').readAsStringSync();
      final widgetSource = File(
        'lib/core/widgets/qr_scanner_widget.dart',
      ).readAsStringSync();

      expect(readerSource, contains('void reset()'));
      expect(widgetSource, contains('_urReader.reset()'));
    });
  });
}
