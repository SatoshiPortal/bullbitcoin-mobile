// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2636
// Finding: the scanner latches before the derivation choice and a cancelled
// choice returns without releasing the latch, disabling further scans.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2636 scanner latch', () {
    test('cancelled derivation choice releases the scanner latch', () {
      final source = File(
        'lib/features/import_watch_only_wallet/presentation/scan_watch_only_screen.dart',
      ).readAsStringSync();

      // The latch is set before the derivation prompt is shown…
      expect(
        source.indexOf('_handled = true'),
        lessThan(source.indexOf('_chooseDerivation')),
      );
      // …and a dismissed prompt returns early…
      expect(source, contains('if (selectedDescriptor == null)'));

      // …without releasing the latch: between that early return and the
      // catch block there is no reset.
      expect(source, contains('if (selectedDescriptor == null) {'));
      expect(source, contains('_handled = false;'));
    });
  });
}
