// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2608
// Finding: multipart UR input is passed to a decoder without a practical sequence-length bound.
// Regression test for the fix.

import 'dart:io';

import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2608 UR sequence bounds', () {
    test('rejects excessive declared sequence lengths before decoding', () {
      final reader = UrQrReader();

      expect(
        () => reader.receive('ur:bytes/1-1001/invalid'),
        throwsA(isA<UrSequenceLimitExceeded>()),
      );
      expect(reader.processedParts, 0);
      expect(reader.expectedParts, isNull);
    });

    test('the pinned fountain decoder is an external unbounded dependency', () {
      final lockfile = File('pubspec.lock').readAsStringSync();

      expect(lockfile, contains('https://github.com/bukata-sa/bc-ur-dart.git'));
      expect(lockfile, contains('5738f70d0ec3d50977ac3dd01fed62939600238b'));
    });
  });
}
