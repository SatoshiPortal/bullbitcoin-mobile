import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Scheduler implements BackgroundTaskScheduler {
  bool failInitialization = false;
  bool initialized = false;
  final cancelled = <String>[];
  final registered = <String>[];
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    if (failInitialization) throw StateError('initialize failed');
    initialized = true;
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    expect(initialized, isTrue, reason: 'initialize before cancellation');
    cancelled.add(uniqueName);
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    registered.add(uniqueName);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'rollout is OFF and cancels persisted work without registering anything',
    () async {
      expect(backgroundSyncEnabled, isFalse);
      final scheduler = Scheduler();
      await applyBackgroundTaskSchedule(
        dispatcher: () {},
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        desktopScheduler: scheduler,
        scheduler: scheduler,
      );
      expect(scheduler.registered, isEmpty);
      expect(
        scheduler.cancelled,
        containsAll(BackgroundTask.values.map((task) => task.id)),
      );
    },
  );
  test('initialization failure never cancels schedules', () async {
    final scheduler = Scheduler()..failInitialization = true;
    await expectLater(
      applyBackgroundTaskSchedule(
        dispatcher: () {},
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        desktopScheduler: scheduler,
        scheduler: scheduler,
      ),
      throwsStateError,
    );
    expect(scheduler.cancelled, isEmpty);
    expect(scheduler.registered, isEmpty);
  });
  test(
    'explicit maintainer activation registers the selected interval',
    () async {
      final scheduler = Scheduler();
      await applyBackgroundTaskSchedule(
        dispatcher: () {},
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        desktopScheduler: scheduler,
        scheduler: scheduler,
        enabled: true,
      );
      expect(scheduler.registered, contains(BackgroundTask.walletsSync.id));
    },
  );
}
