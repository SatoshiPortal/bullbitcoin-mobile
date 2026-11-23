import 'dart:async';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Off cancels an already started registration before completing',
    () async {
      final scheduler = Scheduler()..holdRegistration = true;
      final repository = BackgroundSchedule.open(
        dispatcher: () {},
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        scheduler: scheduler,
        enabled: true,
      );
      final on = repository.setInterval(BackgroundSyncInterval.minutes15);
      await scheduler.entered.future;
      final off = repository.setInterval(BackgroundSyncInterval.off);
      // Let Off reach the scheduler while the old registration is suspended.
      await Future<void>.delayed(Duration.zero);
      scheduler.release.complete();
      expect(await on, isA<Ok>());
      expect(await off, isA<Ok>());
      expect(scheduler.registered, isFalse);
    },
  );

  test('cancellation failure retains persisted Off', () async {
    final directory = await Directory.systemTemp.createTemp('background-off-');
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      await directory.delete(recursive: true);
    });
    final scheduler = Scheduler()..failCancellation = true;
    final repository = BackgroundSchedule.open(
      dispatcher: () {},
      intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
      scheduler: scheduler,
      enabled: true,
    );
    expect(
      await repository.setInterval(BackgroundSyncInterval.off),
      isA<Err>(),
    );
    expect(
      await const SharedPreferencesBackgroundSyncIntervalRepository().read(),
      BackgroundSyncInterval.off,
    );
    expect(scheduler.registered, isTrue);
    final messages = (await log.readLogs())
        .map((row) => row.split('\t')[2])
        .toList();
    expect(messages, contains('Background interval saved=off'));
    expect(
      messages.indexOf('Background interval saved=off'),
      lessThan(messages.indexOf('Background schedule update failed')),
    );
    expect(
      messages,
      isNot(contains('Background schedule applied interval=off')),
    );
  });
}

class Scheduler implements BackgroundTaskSchedulerPort {
  Duration? frequency;
  bool registered = true;
  bool failCancellation = false;
  bool holdInitialization = false;
  bool holdRegistration = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    if (holdInitialization) {
      holdInitialization = false;
      entered.complete();
      await release.future;
    }
  }

  @override
  Future<void> cancelByUniqueName(String name) async {
    if (name == BackgroundTask.walletsSync.id) {
      if (failCancellation) throw Exception('injected cancellation failure');
      registered = false;
    }
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    if (uniqueName == BackgroundTask.walletsSync.id) {
      if (holdRegistration) {
        holdRegistration = false;
        entered.complete();
        await release.future;
      }
      registered = true;
      this.frequency = frequency;
    }
  }
}
