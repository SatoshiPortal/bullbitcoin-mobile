// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2610
// Finding: the Sentry navigation observer can retain route arguments containing
// transaction and wallet identifiers in navigation breadcrumbs.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2610 navigation breadcrumb identifiers', () {
    test(
      'router enables Sentry navigation breadcrumbs while navigation is whitelisted',
      () {
        final router = File('lib/router.dart').readAsStringSync();
        final report = File('lib/core/utils/report.dart').readAsStringSync();

        expect(router, contains('SentryNavigatorObserver'));
        expect(report, contains('message: null'));
        expect(report, contains('data: null'));
      },
    );
  });
}
