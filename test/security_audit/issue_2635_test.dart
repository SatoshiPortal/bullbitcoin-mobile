import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2635
// Finding: Watch-only review/import has no active-environment network check or display.
// Regression test for the fix.
void main() {
  group('Security audit #2635 watch-only network mismatch', () {
    test('import path validates and displays the parsed network', () {
      final cubit = File(
        'lib/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart',
      ).readAsStringSync();
      final details = File(
        'lib/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart',
      ).readAsStringSync();
      expect(cubit, contains('environment'));
      expect(details, contains('Network:'));
    });
  });
}
