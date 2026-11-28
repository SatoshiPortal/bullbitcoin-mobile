import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/background_bootstrap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _UnavailablePaths extends PathProviderPlatform {
  int calls = 0;

  @override
  Future<String?> getApplicationDocumentsPath() async {
    calls++;
    throw StateError('platform resources requested');
  }
}

void main() {
  test('OFF acknowledges persisted work without opening any platform resources', () async {
    final previousPaths = PathProviderPlatform.instance;
    final paths = _UnavailablePaths();
    PathProviderPlatform.instance = paths;
    addTearDown(() => PathProviderPlatform.instance = previousPaths);
    expect(backgroundSyncAvailable, isFalse);
    // No path provider, Drift, native SDK or permission plugin is installed in
    // this test. Building any of the headless graph would fail the test.
    // Ark renewal is admitted independently of the rollout gate, so it is not part of OFF.
    for (final task in BackgroundTask.values.where(
      (task) => task != BackgroundTask.arkRenewal,
    )) {
      final runner = await bootstrapBackgroundRunner(
        task,
        clock: Stopwatch()..start(),
      );
      expect((await runner.run(task)).shouldRetry, isFalse);
      expect(runner.handlers, isEmpty);
    }
    expect(paths.calls, 0);
    await expectLater(
      bootstrapBackgroundRunner(
        BackgroundTask.arkRenewal,
        clock: Stopwatch()..start(),
      ),
      throwsStateError,
    );
    expect(paths.calls, 1);
  });
}
