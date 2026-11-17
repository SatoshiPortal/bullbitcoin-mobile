import 'package:background_tasks/background_tasks.dart';
import 'package:bull_ark/ark_maintenance_setup.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account;

void dispatcher() {}

final class Registry implements ArkAccountRegistryRepository {
  Result<List<ArkAccountConfig>, ArkFailure> result = const Ok([]);
  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async => result;
  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Ok(null);
}

final class Scheduler implements BackgroundTaskSchedulerPort {
  final calls = <String>[];
  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    calls.add('initialize');
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async {
    calls.add('cancel:$uniqueName');
  }

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
    Duration? initialDelay,
  }) async {
    calls.add(
      'register:$uniqueName:$taskName:${frequency.inHours}:$requiresNetwork',
    );
  }
}

void main() {
  test('protected account registers hourly network maintenance', () async {
    final registry = Registry()
      ..result = Ok([
        ArkAccountConfig(
          id: account(),
          arkUrl: Uri.parse('https://ark.example.com'),
          primaryEsploraUrl: Uri.parse('https://chain.example.com'),
        ),
      ]);
    final scheduler = Scheduler();
    expect(
      await scheduleArkMaintenance(
        accounts: registry,
        dispatcher: dispatcher,
        scheduler: scheduler,
      ),
      isA<Ok>(),
    );
    expect(scheduler.calls, [
      'initialize',
      'register:${BackgroundTask.arkRenewal.id}:${BackgroundTask.arkRenewal.name}:1:true',
    ]);
  });

  test('only an authoritative empty registry cancels', () async {
    final registry = Registry();
    final scheduler = Scheduler();
    expect(
      await scheduleArkMaintenance(
        accounts: registry,
        dispatcher: dispatcher,
        scheduler: scheduler,
      ),
      isA<Ok>(),
    );
    expect(scheduler.calls, [
      'initialize',
      'cancel:${BackgroundTask.arkRenewal.id}',
    ]);
    scheduler.calls.clear();
    registry.result = const Err(ArkFeatureStorageFailure());
    expect(
      await scheduleArkMaintenance(
        accounts: registry,
        dispatcher: dispatcher,
        scheduler: scheduler,
      ),
      isA<Err>(),
    );
    expect(scheduler.calls, isEmpty);
  });
}
