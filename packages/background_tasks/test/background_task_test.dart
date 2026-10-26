import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Logger implements BackgroundTaskLogger {
  final messages = <String>[];
  var flushes = 0;
  bool throwOnFlush = false;

  @override
  void info(String message) => messages.add(message);

  @override
  void warning(String message) => messages.add(message);

  @override
  Future<void> flush() async {
    flushes++;
    if (throwOnFlush) throw StateError('flush failure');
  }
}

final class _Scheduler implements BackgroundTaskScheduler {
  BackgroundTaskDispatcher? dispatcher;
  final cancelled = <String>[];
  final registrations =
      <({String name, String task, bool network, Duration frequency})>[];

  @override
  Future<void> initialize(BackgroundTaskDispatcher dispatcher) async {
    this.dispatcher = dispatcher;
  }

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);

  @override
  Future<void> registerPeriodic({
    required String uniqueName,
    required String taskName,
    required Duration frequency,
    required bool requiresNetwork,
  }) async => registrations.add((
    name: uniqueName,
    task: taskName,
    network: requiresNetwork,
    frequency: frequency,
  ));
}

BackgroundTaskExecutionResult _resultFor(
  BackgroundTaskExecutionStatus status,
) => switch (status) {
  BackgroundTaskExecutionStatus.success =>
    const BackgroundTaskExecutionResult.success(),
  BackgroundTaskExecutionStatus.retry =>
    const BackgroundTaskExecutionResult.retry(),
  BackgroundTaskExecutionStatus.permanentFailure =>
    const BackgroundTaskExecutionResult.permanentFailure(),
};

void main() {
  test('resolves short names and iOS identifiers, but not unknown values', () {
    expect(BackgroundTask.resolve('bitcoin-sync'), BackgroundTask.bitcoinSync);
    expect(
      BackgroundTask.resolve('com.bullbitcoin.mobile.liquid-sync-id'),
      BackgroundTask.liquidSync,
    );
    expect(BackgroundTask.resolve('not-a-task'), isNull);
  });

  for (final expected in [
    BackgroundTaskExecutionStatus.success,
    BackgroundTaskExecutionStatus.permanentFailure,
    BackgroundTaskExecutionStatus.retry,
  ]) {
    test('flushes and finishes exactly once for $expected', () async {
      final logger = _Logger();
      var finishes = 0;
      final runner = BackgroundTaskRunner(
        logger: logger,
        onFinished: () async => finishes++,
        handlers: {
          BackgroundTask.bitcoinSync: () async => _resultFor(expected),
        },
      );

      final result = await runner.run('bitcoin-sync');

      expect(result.status, expected);
      expect(logger.flushes, 1);
      expect(finishes, 1);
    });
  }

  test('flushes and finishes once when the handler throws', () async {
    final logger = _Logger();
    var finishes = 0;
    final result = await BackgroundTaskRunner(
      logger: logger,
      onFinished: () async => finishes++,
      handlers: {
        BackgroundTask.swapsSync: () => throw StateError('test-only failure'),
      },
    ).run('swaps-sync');

    expect(result.status, BackgroundTaskExecutionStatus.retry);
    expect(logger.flushes, 1);
    expect(finishes, 1);
    expect(logger.messages, isNot(contains(contains('test-only'))));
  });

  test('flush failure does not prevent cleanup and returns retry', () async {
    final logger = _Logger()..throwOnFlush = true;
    var finishes = 0;
    final result = await BackgroundTaskRunner(
      logger: logger,
      onFinished: () async => finishes++,
      handlers: {
        BackgroundTask.bitcoinSync: () async =>
            const BackgroundTaskExecutionResult.success(),
      },
    ).run('bitcoin-sync');

    expect(result.status, BackgroundTaskExecutionStatus.retry);
    expect(logger.flushes, 1);
    expect(finishes, 1);
  });

  test('cleanup failure returns retry without throwing', () async {
    final logger = _Logger();
    final result = await BackgroundTaskRunner(
      logger: logger,
      onFinished: () async => throw StateError('cleanup failure'),
      handlers: {
        BackgroundTask.liquidSync: () async =>
            const BackgroundTaskExecutionResult.permanentFailure(),
      },
    ).run('liquid-sync');

    expect(result.status, BackgroundTaskExecutionStatus.retry);
    expect(logger.flushes, 1);
  });

  test('unknown tasks are permanently acknowledged and cannot loop', () async {
    final logger = _Logger();
    final result = await BackgroundTaskRunner(
      logger: logger,
      handlers: {},
    ).run('unknown');
    expect(result.status, BackgroundTaskExecutionStatus.permanentFailure);
    expect(logger.flushes, 1);
  });

  test(
    'maps WorkManager outcomes without leaking bootstrap exceptions',
    () async {
      final logger = _Logger();
      BackgroundTaskRunner runner(BackgroundTaskExecutionResult result) =>
          BackgroundTaskRunner(
            logger: logger,
            handlers: {BackgroundTask.bitcoinSync: () async => result},
          );
      expect(
        await mapBackgroundTaskResult(
          'bitcoin-sync',
          () async => runner(const BackgroundTaskExecutionResult.retry()),
        ),
        isFalse,
      );
      expect(
        await mapBackgroundTaskResult(
          'bitcoin-sync',
          () async => runner(const BackgroundTaskExecutionResult.success()),
        ),
        isTrue,
      );
      expect(
        await mapBackgroundTaskResult(
          'bitcoin-sync',
          () async =>
              runner(const BackgroundTaskExecutionResult.permanentFailure()),
        ),
        isTrue,
      );
      expect(
        await mapBackgroundTaskResult(
          'bitcoin-sync',
          () async => throw StateError('secret'),
        ),
        isFalse,
      );
      expect(
        await mapBackgroundTaskResult(
          'bitcoin-sync',
          () async => BackgroundTaskRunner(
            logger: logger,
            onFinished: () async => throw StateError('cleanup'),
            handlers: {
              BackgroundTask.bitcoinSync: () async =>
                  const BackgroundTaskExecutionResult.success(),
            },
          ),
        ),
        isFalse,
      );
    },
  );

  test('keeps scheduling generic and hides WorkManager details', () async {
    final scheduler = _Scheduler();
    final adapter = BackgroundTaskWorkmanagerAdapter(scheduler: scheduler);

    await adapter.initialize(() {});
    await adapter.cancelByUniqueName('legacy-swaps');
    await adapter.registerPeriodicTask(
      uniqueName: 'bitcoin',
      taskName: 'bitcoin-sync',
      requiresNetwork: true,
    );
    await adapter.registerPeriodicTask(
      uniqueName: 'logs',
      taskName: 'logs-prune',
      frequency: const Duration(days: 1),
    );

    expect(scheduler.dispatcher, isNotNull);
    expect(scheduler.cancelled, ['legacy-swaps']);
    expect(scheduler.registrations, [
      (
        name: 'bitcoin',
        task: 'bitcoin-sync',
        network: true,
        frequency: const Duration(hours: 1),
      ),
      (
        name: 'logs',
        task: 'logs-prune',
        network: false,
        frequency: const Duration(days: 1),
      ),
    ]);
  });
}
