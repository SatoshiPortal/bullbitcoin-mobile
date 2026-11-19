import 'dart:async';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

void dispatcher() {}

class Scheduler implements BackgroundTaskSchedulerPort {
  final cancelled = <String>[];
  final registered = <String>[];
  Completer<void>? initialization;
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    await initialization?.future;
  }

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
    expect(frequency, const Duration(hours: 1));
    expect(requiresNetwork, true);
    registered.add(uniqueName);
  }
}

void main() {
  test(
    'Ark task resolves independently and never enables ordinary sync',
    () async {
      expect(BackgroundTask.resolve('ark-renewal'), BackgroundTask.arkRenewal);
      final scheduler = Scheduler();
      await applyArkRenewalSchedule(
        dispatcher: dispatcher,
        renewalRequired: true,
        scheduler: scheduler,
      );
      expect(scheduler.registered, [BackgroundTask.arkRenewal.id]);
      expect(scheduler.cancelled, isEmpty);
    },
  );
  test('disabled empty inventory cancels only Ark work', () async {
    final scheduler = Scheduler();
    await applyArkRenewalSchedule(
      dispatcher: dispatcher,
      renewalRequired: false,
      scheduler: scheduler,
    );
    expect(scheduler.cancelled, [BackgroundTask.arkRenewal.id]);
    expect(scheduler.registered, isEmpty);
  });
  test(
    'obsolete delayed activation cannot revive a cancelled schedule',
    () async {
      final old = Scheduler()..initialization = Completer<void>();
      final enable = applyArkRenewalSchedule(
        dispatcher: dispatcher,
        renewalRequired: true,
        scheduler: old,
      );
      final latest = Scheduler();
      await applyArkRenewalSchedule(
        dispatcher: dispatcher,
        renewalRequired: false,
        scheduler: latest,
      );
      old.initialization?.complete();
      await enable;
      expect(old.registered, isEmpty);
      expect(latest.cancelled, [BackgroundTask.arkRenewal.id]);
    },
  );
  test(
    'closed headless resources revoke further native-stage admission',
    () async {
      final resources = BackgroundTaskResources();
      expect(resources.mayAdmitNextStage, true);
      expect(
        resources.remainingBudget.inMicroseconds,
        inInclusiveRange(0, backgroundRunBudget.inMicroseconds),
      );
      await resources.close();
      expect(resources.mayAdmitNextStage, false);
    },
  );
}
