// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2643
// Finding: consent copy promises anonymized reporting without describing the
// transaction-related metadata retained by navigation breadcrumbs.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2643 error-reporting consent copy', () {
    test('copy precisely describes minimized metadata', () {
      final localization = File('localization/app_en.arb').readAsStringSync();
      expect(
        localization,
        contains('minimized error reports containing app version'),
      );
      expect(
        localization,
        contains('Wallet and transaction payloads are removed.'),
      );
    });
  });
}
