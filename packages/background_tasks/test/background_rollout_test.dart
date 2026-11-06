import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Scheduler implements BackgroundTaskScheduler {
  final cancelled = <String>[];
  final registered = <String>[];
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {}
  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
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
  test(
    'explicit maintainer activation registers the selected interval',
    () async {
      final scheduler = Scheduler();
      await applyBackgroundTaskSchedule(
        dispatcher: () {},
        desktopScheduler: scheduler,
        scheduler: scheduler,
        enabled: true,
      );
      expect(scheduler.registered, contains(BackgroundTask.walletsSync.id));
    },
  );
}
