import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2612
// Finding: iOS registered background tasks natively before Dart initialized its dependencies.
// Regression test for the fix.
void main() {
  group('Security audit #2612 startup background tasks', () {
    test('background tasks are registered from Dart after initialization', () {
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
      ).readAsStringSync();
      final initialization = File('lib/init.dart').readAsStringSync();
      final handler = File(
        'lib/core/background_tasks/handler.dart',
      ).readAsStringSync();

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

      final setup = initialization.indexOf('await AppLocator.setup(');
      final registration = initialization.indexOf(
        'await registerBackgroundTasks();',
      );
      expect(setup, greaterThanOrEqualTo(0));
      expect(registration, greaterThan(setup));

      final adapter = handler.indexOf('BackgroundTaskWorkmanagerAdapter()');
      final legacyCancellation = handler.indexOf(
        'cancelByUniqueName(BackgroundTask.swapsSync.id)',
      );
      final periodic = handler.indexOf('registerPeriodicTask(');
      expect(adapter, greaterThanOrEqualTo(0));
      expect(legacyCancellation, greaterThan(adapter));
      expect(periodic, greaterThan(legacyCancellation));
      expect(handler, isNot(contains('Workmanager().cancelAll()')));
      expect(
        handler.indexOf('cancelByUniqueName(BackgroundTask.liquidSync.id)'),
        allOf(greaterThan(adapter), lessThan(periodic)),
      );
      expect(
        handler,
        isNot(contains('uniqueName: BackgroundTask.liquidSync.id')),
      );
    });
  });
}
