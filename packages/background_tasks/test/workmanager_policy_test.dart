import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:workmanager/workmanager.dart';

class _Platform extends WorkmanagerPlatform with MockPlatformInterfaceMixin {
  final policies = <String, ExistingPeriodicWorkPolicy?>{};

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    policies[uniqueName] = existingWorkPolicy;
  }
}

void main() {
  test('a new interval replaces the one already scheduled', () async {
    // Creating the plugin first lets it pick its platform, which the fake
    // then replaces.
    final adapter = BackgroundTaskWorkmanagerAdapter();
    final platform = _Platform();
    WorkmanagerPlatform.instance = platform;

    await adapter.registerPeriodicTask(
      uniqueName: 'bitcoin',
      taskName: 'bitcoin-sync',
      frequency: const Duration(minutes: 30),
    );

    // KEEP would leave installed work on its old interval.
    expect(platform.policies['bitcoin'], ExistingPeriodicWorkPolicy.update);
  });
}
