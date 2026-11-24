import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2612
// Finding: iOS registers disabled background tasks before Dart can cancel them after initialization.
// Under the UIScene lifecycle a fresh install must register its launch handlers natively, or iOS aborts when Dart submits the first request.
// A launch handler schedules nothing: Dart still submits or cancels each task, and the background runner refuses work when the rollout gate is off or the user chose no interval.
// So AppDelegate registers exactly the tasks Dart schedules on iOS, and never the legacy ones.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security audit #2612 startup background tasks', () {
    final appDelegate = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final registered = RegExp(r'"(com\.bullbitcoin\.mobile\.[a-z-]+)"')
        .allMatches(appDelegate)
        .map((match) => match.group(1))
        .toSet();

    test('registers exactly the tasks Dart schedules on iOS', () {
      expect(registered, {
        BackgroundTask.walletsSync.id,
        BackgroundTask.logsPrune.id,
      });
    });

    test('never registers legacy or Android-only tasks natively', () {
      for (final task in [
        BackgroundTask.bitcoinSync,
        BackgroundTask.liquidSync,
        BackgroundTask.swapsSync,
        BackgroundTask.arkRenewal,
      ]) {
        expect(appDelegate, isNot(contains(task.id)), reason: task.name);
      }
    });

    test('every registered task is permitted in Info.plist', () {
      for (final id in registered) {
        expect(infoPlist, contains('<string>$id</string>'), reason: id);
      }
    });

    // The plugin keeps the delay from the first registration in a launch, so the saved one must come first.
    test('saved launch handlers are registered before the native list', () {
      final saved = appDelegate.indexOf(
        'WorkmanagerPlugin.registerLaunchHandlers()',
      );
      final native = appDelegate.indexOf(
        'WorkmanagerPlugin.registerPeriodicTask(withIdentifier:',
      );
      expect(saved, greaterThanOrEqualTo(0));
      expect(native, greaterThan(saved));
    });

    test('legacy cancellation starts after application setup', () {
      final initialization = File('lib/init.dart').readAsStringSync();
      final setup = initialization.indexOf('await AppLocator.setup(');
      final cancellation = initialization.indexOf(
        'await locator<BackgroundSchedule>().apply();',
      );
      expect(setup, greaterThanOrEqualTo(0));
      expect(cancellation, greaterThan(setup));
    });
  });
}
