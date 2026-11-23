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
        'features/wallet_import/lib/src/ui/watch_only/scan_watch_only_screen.dart',
      ).readAsStringSync();

      // The latch is set before reading the QR, including the derivation prompt.
      expect(
        source.indexOf('_handled = true'),
        lessThan(source.indexOf('await readWatchOnlyQr')),
      );
      expect(source, contains(RegExp(r'else\s*\{\s*_handled = false;')));
    });
  });
}
