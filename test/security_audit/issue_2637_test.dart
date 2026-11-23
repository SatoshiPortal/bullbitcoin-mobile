// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2637
// Finding: a failed UR decode updates the error UI but never resets the reader.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2637 UR scanner recovery', () {
    test('scanner resets the reader and reports a processing error', () {
      final source = File('features/scanning/lib/src/qr_scanner_widget.dart')
          .readAsStringSync();
      final catchStart = source.indexOf('} catch (e) {');
      expect(catchStart, isNonNegative);
      final catchBody = source.substring(catchStart);

      expect(catchBody, contains('_urReader.reset()'));
      expect(catchBody, contains('widget.labels.urProcessingFailedMessage'));
    });

    test('scanner resets the reader before delivering a decoded result', () {
      final readerSource = File('features/signers/lib/src/urqr/urqr.dart')
          .readAsStringSync();
      final widgetSource = File(
        'features/scanning/lib/src/qr_scanner_widget.dart',
      ).readAsStringSync();

      expect(readerSource, contains('void reset()'));
      expect(
        widgetSource,
        matches(
          RegExp(r'_urReader\.reset\(\);\s+widget\.onScanned\(decoded\);'),
        ),
      );
    });
  });
}
