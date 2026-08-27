import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2612
// Finding: iOS registers disabled background tasks before Dart can cancel them after initialization.
// Regression test for the fix.
void main() {
  group('Security audit #2612 startup background tasks', () {
    test('disabled background tasks are not registered natively', () {
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final main = File('lib/main.dart').readAsStringSync();

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

      final initEnd = main.indexOf('await initLocator(');
      final workmanagerInit = main.indexOf('await initWorkmanager();');
      final cancellation = main.indexOf('await Workmanager().cancelAll();');
      expect(initEnd, greaterThanOrEqualTo(0));
      expect(workmanagerInit, greaterThan(initEnd));
      expect(cancellation, greaterThan(workmanagerInit));
    });
  });
}
