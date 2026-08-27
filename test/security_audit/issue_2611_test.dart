// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2611
// Finding: Sentry's native SDK is initialized in release mode before user consent
// is known, allowing native crash handling to bypass the Dart consent gate.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2611 native Sentry consent', () {
    test('native integrations are consent-gated', () {
      final source = File('lib/core/utils/report.dart').readAsStringSync();

      expect(source, contains('await SentryFlutter.init((options)'));
      expect(source, contains('options.dsn = kReleaseMode ?'));
      expect(source, contains('final consent = Report.consent'));
      expect(source, contains('options.anrEnabled = consent'));
      expect(
        source,
        contains('options.enableWatchdogTerminationTracking = consent'),
      );
      expect(source, contains('options.enableAppHangTracking = consent'));
    });
  });
}
