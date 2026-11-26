// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2611
// The native SDK must only start after startup consent is known and enabled.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2611 native Sentry consent', () {
    test('startup checks consent before initializing either SDK', () {
      final source = File('packages/bull_reporting/lib/src/report.dart')
          .readAsStringSync();
      final start = source.indexOf('static Future<void> init(');
      final end = source.indexOf('static String _generateInstallUuid()');
      final startup = source.substring(start, end);

      expect(
        startup,
        contains('wizardConsent ?? prefs.getBool(_consentKey) ?? false'),
      );
      final apply = startup.indexOf('await _applyConsent(bootConsent);');
      final guard = startup.indexOf(
        'if (!kReleaseMode || dsn.isEmpty || !consent || _started) return;',
      );
      final initialize = startup.indexOf('await _initSentry(dsn);');
      expect(apply, greaterThanOrEqualTo(0));
      expect(guard, greaterThan(apply));
      expect(initialize, greaterThan(guard));
      expect("await _initSentry(dsn);".allMatches(source), hasLength(1));
    });

    test('the native bridge owns initialization and shutdown', () {
      final source = File('packages/bull_reporting/lib/src/report.dart')
          .readAsStringSync();

      expect(source, contains('options.autoInitializeNativeSdk = false;'));
      expect(source, contains("invokeMethod<void>('start', dsn)"));
      expect(source, contains("invokeMethod<void>('close')"));
      expect(source, contains('if (!enabled) await _stopReporting();'));
    });
  });
}
