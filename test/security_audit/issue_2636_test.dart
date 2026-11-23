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

      final latch = source.indexOf('_handled = true;');
      final read = source.indexOf('await readWatchOnlyQr(');
      expect(latch, greaterThanOrEqualTo(0));
      expect(read, greaterThan(latch));

      final qr = File('features/wallet_import/lib/src/ui/watch_only_qr.dart')
          .readAsStringSync();
      expect(qr, contains('return Ok(choice);'));
      expect(
        qr,
        contains(
          'if (input == null || !context.mounted) return const Ok(null);',
        ),
      );
      expect(
        source.substring(read),
        matches(
          RegExp(
            r'if \(watchOnly case Ok\(value: final value\?\)\) \{\s*'
            r'ImportNavigation\.replaceWithWatchOnly\(context, value\);\s*'
            r'\} else \{\s*_handled = false;',
          ),
        ),
      );
    });
  });
}
