import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/background_tasks/handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:workmanager/workmanager.dart';

class _ControlledWorkmanagerPlatform extends WorkmanagerPlatform {
  final initialization = Completer<void>();
  final cancellation = Completer<void>();
  final calls = <String>[];
  Function? callbackDispatcher;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) {
    calls.add('initialize');
    this.callbackDispatcher = callbackDispatcher;
    return initialization.future;
  }

  @override
  Future<void> cancelAll() {
    calls.add('cancelAll');
    return cancellation.future;
  }
}

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2612
// Finding: iOS registers disabled background tasks before Dart can cancel them after initialization.
// Regression test for the fix.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security audit #2612 startup background tasks', () {
    test('disabled background tasks are not registered natively', () {
      final appDelegate = File(
        'ios/Runner/AppDelegate.swift',
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
    });

    test('legacy cancellation starts after application setup', () {
      final initialization = File('lib/init.dart').readAsStringSync();
      final setup = initialization.indexOf('await AppLocator.setup(');
      final cancellation = initialization.indexOf(
        'await cancelLegacyBackgroundTasks();',
      );
      expect(setup, greaterThanOrEqualTo(0));
      expect(cancellation, greaterThan(setup));
    });

    group('legacy schedule cancellation', () {
      late WorkmanagerPlatform originalPlatform;
      late _ControlledWorkmanagerPlatform platform;

      setUp(() {
        // Construct the singleton before installing the fake so macOS does not replace it with its native implementation.
        Workmanager();
        originalPlatform = WorkmanagerPlatform.instance;
        platform = _ControlledWorkmanagerPlatform();
        WorkmanagerPlatform.instance = platform;
      });

      tearDown(() {
        WorkmanagerPlatform.instance = originalPlatform;
      });

      test('awaits initialization and cancellation', () async {
        var completed = false;
        final result = cancelLegacyBackgroundTasks().then((_) {
          completed = true;
        });

        await pumpEventQueue();
        expect(platform.callbackDispatcher, same(backgroundTasksHandler));
        expect(platform.calls, ['initialize']);
        expect(completed, isFalse);

        platform.initialization.complete();
        await pumpEventQueue();
        expect(platform.calls, ['initialize', 'cancelAll']);
        expect(completed, isFalse);

        platform.cancellation.complete();
        await result;
        expect(completed, isTrue);
      });

      test('does not cancel when initialization fails', () async {
        final error = StateError('Workmanager initialization failed');
        final result = expectLater(
          cancelLegacyBackgroundTasks(),
          throwsA(same(error)),
        );

        platform.initialization.completeError(error);

        await result;
        expect(platform.calls, ['initialize']);
      });
    });
  });
}
