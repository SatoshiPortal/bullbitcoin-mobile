import 'dart:async';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an unset or unknown interval reads as one hour', () async {
    const store = SharedPreferencesBackgroundSyncIntervalStore();
    expect(await store.read(), BackgroundSyncInterval.hour1);

    SharedPreferences.setMockInitialValues({
      'background_sync_interval': 'minutes7',
    });
    expect(await store.read(), BackgroundSyncInterval.hour1);
  });

  test('a chosen interval survives a reread', () async {
    const store = SharedPreferencesBackgroundSyncIntervalStore();
    await store.write(BackgroundSyncInterval.minutes15);
    expect(await store.read(), BackgroundSyncInterval.minutes15);
    await store.write(BackgroundSyncInterval.off);
    expect(await store.read(), BackgroundSyncInterval.off);
    expect(BackgroundSyncInterval.off.frequency, isNull);
  });

  test('the desktop timer runs a task without overlapping it', () async {
    final release = Completer<void>();
    var ticks = 0;
    final scheduler = TimerBackgroundTaskScheduler(
      onTick: (taskName) async {
        expect(taskName, 'bitcoin-sync');
        ticks++;
        await release.future;
      },
    );
    await scheduler.registerPeriodic(
      uniqueName: 'bitcoin',
      taskName: 'bitcoin-sync',
      frequency: const Duration(milliseconds: 10),
      requiresNetwork: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(ticks, 1);
    release.complete();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(ticks, greaterThan(1));

    await scheduler.cancelByUniqueName('bitcoin');
    final stopped = ticks;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(ticks, stopped);
  });
}
