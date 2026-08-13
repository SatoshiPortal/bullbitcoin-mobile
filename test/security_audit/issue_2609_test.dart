// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2609
// Finding: beforeSend mutates stack-frame vars before breadcrumb scrubbing, so an
// unmodifiable vars map can throw and cause Sentry to send a partially scrubbed event.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2609 Sentry scrub ordering', () {
    test('source minimizes breadcrumbs before guarded frame scrubbing', () {
      final source = File('lib/core/utils/report.dart').readAsStringSync();
      final frameMutation = source.indexOf('f.vars.clear()');
      final breadcrumbScrub = source.indexOf('event.breadcrumbs =');

      expect(frameMutation, isNonNegative);
      expect(breadcrumbScrub, isNonNegative);
      expect(frameMutation, greaterThan(breadcrumbScrub));
      expect(source, contains('event.breadcrumbs = event.breadcrumbs?.map'));
    });
  });
}
