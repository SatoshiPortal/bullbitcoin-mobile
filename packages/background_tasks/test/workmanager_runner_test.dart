import 'dart:io';

import 'package:legacy_storage/coordination.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:primitives/primitives.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persisted Off acknowledges wallet callback before building its graph',
    () async {
      expect(
        await const SharedPreferencesBackgroundSyncIntervalRepository().write(
          BackgroundSyncInterval.off,
        ),
        isA<Ok>(),
      );
      final logger = _Logger();
      final runner = await BackgroundTaskRunner.forTask(
        task: BackgroundTask.walletsSync,
        logger: logger,
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        tasks: {
          BackgroundTask.walletsSync: (_) async =>
              fail('wallet graph opened after opt-out'),
        },
      );
      expect(
        (await runner.run(BackgroundTask.walletsSync)).shouldRetry,
        isFalse,
      );
      expect(runner.handlers, isEmpty);
      expect(
        logger.messages,
        contains('Background admission stopped: category=opt_out'),
      );
    },
  );

  test('unknown and obsolete tasks never build a graph', () async {
    for (final task in ['unknown', BackgroundTask.swapsSync.id]) {
      var bootstrapped = false;
      expect(
        await mapBackgroundTaskResult(task, (_) async {
          bootstrapped = true;
          throw StateError('must not bootstrap');
        }),
        isTrue,
      );
      expect(bootstrapped, isFalse);
    }
  });

  test('selects the log task before opening resources', () async {
    final events = <String>[];
    final result = await mapBackgroundTaskResult(
      BackgroundTask.logsPrune.id,
      (task) => BackgroundTaskRunner.forTask(
        task: task,
        logger: _Logger(),
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        tasks: {
          BackgroundTask.walletsSync: (_) async {
            fail('wallet graph opened for log pruning');
          },
          BackgroundTask.logsPrune: (resources) async {
            events.add('open logs');
            resources.onClose(() => events.add('close logs'));
            return () async {
              events.add('prune');
              return const BackgroundTaskExecutionResult.success();
            };
          },
        },
      ),
    );
    expect(result, isTrue);
    expect(events, ['open logs', 'prune', 'close logs']);
  });

  test('partial startup unwinds in reverse even when disposal fails', () async {
    final events = <String>[];
    final startupFailure = Exception('startup');
    await expectLater(
      BackgroundTaskRunner.forTask(
        task: BackgroundTask.walletsSync,
        logger: _Logger(),
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        tasks: {
          BackgroundTask.walletsSync: (resources) async {
            resources.onClose(() => events.add('catalog'));
            resources.onClose(() {
              events.add('connection');
              throw Exception('dispose');
            });
            resources.onClose(() => events.add('queue'));
            throw startupFailure;
          },
        },
      ),
      throwsA(same(startupFailure)),
    );
    expect(events, ['queue', 'connection', 'catalog']);
  });

  test(
    'dispatcher retries when a successful task cannot close its resources',
    () async {
      expect(
        await mapBackgroundTaskResult(
          BackgroundTask.logsPrune.id,
          (_) async => BackgroundTaskRunner(
            logger: _Logger(),
            handlers: {
              BackgroundTask.logsPrune: () async =>
                  const BackgroundTaskExecutionResult.success(),
            },
            onFinished: () async {
              throw const LifecycleException('resources_still_open');
            },
          ),
        ),
        isFalse,
      );
    },
  );

  test(
    'failed native cleanup retains admission through generic resource cleanup',
    () async {
      final directory = await Directory.systemTemp.createTemp('worker-lease-');
      final gate = NativeFileGate(File('${directory.path}/gate'));
      final admission = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      var live = true;
      final result = await mapBackgroundTaskResult(
        BackgroundTask.logsPrune.id,
        (task) => BackgroundTaskRunner.forTask(
          task: task,
          logger: _Logger(),
          admission: admission,
          intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
          tasks: {
            task: (resources) async {
              resources.onClose(() {
                if (live) throw const LifecycleException('handle_alive');
              });
              return () async => const BackgroundTaskExecutionResult.success();
            },
          },
        ),
      );
      expect(result, isFalse);
      await expectLater(
        gate.acquire(exclusive: true, timeout: Duration.zero),
        throwsA(isA<LifecycleException>()),
      );
      live = false;
      await LifecycleAdmission.retryQuarantined();
      await (await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      )).close();
      await directory.delete(recursive: true);
    },
  );

  test('cleanup is idempotent and rejects late registration', () async {
    final resources = BackgroundTaskResources();
    var closes = 0;
    resources.onClose(() => closes++);
    await resources.close();
    await resources.close();
    expect(closes, 1);
    expect(() => resources.onClose(() {}), throwsStateError);
  });
}

final class _Logger implements BackgroundTaskLoggerPort {
  final messages = <String>[];
  @override
  void write(BackgroundLogLevel level, String message) => messages.add(message);
  @override
  Future<void> flush() async {}
}
