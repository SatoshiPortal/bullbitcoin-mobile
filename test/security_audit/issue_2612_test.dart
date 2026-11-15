import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2612
// Finding: iOS registers disabled background tasks before Dart can cancel them after initialization.
// Regression test for the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security audit #2612 startup background tasks', () {
    test('disabled background tasks are not registered natively', () {
      final appDelegate = File('ios/Runner/AppDelegate.swift')
          .readAsStringSync();
      expect(
        appDelegate,
        isNot(contains('WorkmanagerPlugin.registerPeriodicTask')),
      );
      expect(
        appDelegate,
        isNot(contains('com.bullbitcoin.mobile.bitcoin-sync-id')),
      );
      expect(
        appDelegate,
        isNot(contains('com.bullbitcoin.mobile.liquid-sync-id')),
      );
      expect(
        appDelegate,
        isNot(contains('com.bullbitcoin.mobile.swaps-sync-id')),
      );
      expect(
        appDelegate,
        isNot(contains('com.bullbitcoin.mobile.logs-prune-id')),
      );
    });

    test('legacy cancellation starts after application setup', () {
      final initialization = File('lib/init.dart').readAsStringSync();
      final setup = initialization.indexOf('await AppLocator.setup(');
      final cancellation = initialization.indexOf(
        'await configureBackgroundTasks();',
      );
      expect(setup, greaterThanOrEqualTo(0));
      expect(cancellation, greaterThan(setup));
    });
  });
}
