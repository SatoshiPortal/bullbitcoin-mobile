import 'package:bull_logger/bull_logger.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late WalletSyncJobQueueRepository queue;
  late _Writer writer;
  late _Revisions revisions;
  late _Announcements announcements;
  late _Logs logs;
  final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
  final second = WalletKey(id: 'second', network: BitcoinNetwork.testnet);
  WalletRevision stamp(int revision) =>
      WalletRevision(key: key, generation: 1, revision: revision);
  BackgroundSyncOutcome outcome({
    List<String>? incoming = const ['old', 'new'],
  }) => BackgroundSyncOutcome(
    revision: stamp(2),
    incomingTxids: incoming,
    completedAt: DateTime.utc(2026),
  );
  RunWalletSyncJobsUsecase task({Duration? budget, List<WalletKey>? keys}) =>
      RunWalletSyncJobsUsecase(
        wallets: writer,
        revisions: revisions,
        keys: keys ?? [key],
        queue: queue,
        intervals: const SharedPreferencesBackgroundSyncIntervalRepository(),
        announcements: announcements,
        logger: logs,
        runBudget: budget,
      );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    directory = Directory.systemTemp.createTempSync('background-task-');
    log = Logger.replace(directory: directory);
    queue = _ok(
      SqliteWalletSyncJobQueueRepository.openForeground(
        '${directory.path}/queue',
      ),
    );
    writer = _Writer();
    logs = _Logs();
    revisions = _Revisions();
    announcements = _Announcements();
  });
  tearDown(() async {
    await log.flush();
    await queue.close();
    directory.deleteSync(recursive: true);
  });

  test(
    'persisted Off prevents a surviving callback from admitting work',
    () async {
      expect(
        await const SharedPreferencesBackgroundSyncIntervalRepository().write(
          BackgroundSyncInterval.off,
        ),
        isA<Ok>(),
      );
      writer.operation = () async => Ok(outcome());
      expect((await task().execute()).shouldRetry, isFalse);
      expect(writer.allowInitialScan, isEmpty);
      expect(
        logs.entries,
        contains((
          BackgroundLogLevel.fine,
          'Background admission stopped: category=opt_out',
        )),
      );
    },
  );

  test(
    'Off during admitted work waits for completion and stops further wallets',
    () async {
      final started = Completer<void>();
      final release = Completer<void>();
      writer.operation = () async {
        if (!started.isCompleted) started.complete();
        await release.future;
        return Ok(
          BackgroundSyncOutcome(
            revision: WalletRevision(
              key: writer.allowInitialScan.length == 1 ? key : second,
              generation: 1,
              revision: 2,
            ),
            incomingTxids: null,
            completedAt: DateTime.utc(2026),
          ),
        );
      };
      var finished = false;
      final run = task(
        keys: [key, second],
      ).execute().then((_) => finished = true);
      await started.future;
      expect(
        await const SharedPreferencesBackgroundSyncIntervalRepository().write(
          BackgroundSyncInterval.off,
        ),
        isA<Ok>(),
      );
      expect(finished, isFalse);
      release.complete();
      await run;
      expect(writer.allowInitialScan, [false]);
      expect(
        logs.entries,
        contains((
          BackgroundLogLevel.fine,
          'Background admission stopped: category=opt_out',
        )),
      );
    },
  );

  for (final pending in [true, false]) {
    test(
      'unavailable wallet does not block healthy wallet (pending=$pending)',
      () async {
        final disabled = (_ok(
          await queue.reconcileAndClaim([
            stamp(1),
          ], chain: WalletSyncChain.bitcoin),
        )).single;
        expect(
          await queue.completeFailure(disabled, permanent: true),
          isA<Ok>(),
        );
        revisions.unavailable = key;
        revisions.pending = pending;
        writer.operation = () async => Ok(
          BackgroundSyncOutcome(
            revision: WalletRevision(key: second, generation: 1, revision: 2),
            incomingTxids: null,
            completedAt: DateTime.utc(2026),
          ),
        );
        await task(keys: [key, second]).execute();
        expect(writer.allowInitialScan, [false]);
        revisions.unavailable = null;
        // A temporary read failure must not erase the permanent retry state.
        final claims = _ok(
          await queue.reconcileAndClaim([
            stamp(1),
          ], chain: WalletSyncChain.bitcoin),
        );
        expect(claims, isEmpty);
      },
    );
  }

  test(
    'unavailable unseen wallet cannot block a previously synced wallet',
    () async {
      final healthy = WalletRevision(key: second, generation: 1, revision: 1);
      final claims = _ok(
        await queue.reconcileAndClaim([
          stamp(1),
          healthy,
        ], chain: WalletSyncChain.bitcoin),
      );
      for (final claim in claims) {
        if (claim.key == key) {
          expect(await queue.release(claim), isA<Ok>());
        } else {
          expect(await queue.completeSuccess(claim), isA<Ok>());
        }
      }
      revisions.unavailable = key;
      writer.operation = () async => Ok(
        BackgroundSyncOutcome(
          revision: healthy,
          incomingTxids: null,
          completedAt: DateTime.utc(2026),
        ),
      );
      await task(keys: [key, second]).execute();
      expect(writer.allowInitialScan, [false]);
    },
  );

  test(
    'background run asks for revealed scripts but never an initial scan',
    () async {
      writer.operation = () async => Ok(outcome());
      await task().execute();
      expect(writer.discover, [false]);
      expect(writer.allowInitialScan, [false]);
    },
  );

  test(
    'a committed sync is recorded, then announcements are delivered',
    () async {
      writer.operation = () async => Ok(outcome());
      expect((await task().execute()).shouldRetry, isFalse);
      expect(writer.allowInitialScan, [false]);
      expect(
        logs.entries.any(
          (e) =>
              e.$1 == BackgroundLogLevel.fine && e.$2.contains('job finished'),
        ),
        isTrue,
      );
      expect(logs.entries.any((e) => e.$2.contains(key.id)), isFalse);
      expect(announcements.recorded.single.incomingTxids, {'old', 'new'});
      // After each chain.
      expect(announcements.deliveries, WalletSyncChain.values.length);
    },
  );

  test('announcement programmer errors propagate', () async {
    writer.operation = () async => Ok(outcome());
    announcements.recording = () => throw StateError('private');
    await expectLater(task().execute(), throwsStateError);
  });

  test('a failed announcement record cannot retry a committed sync', () async {
    writer.operation = () async => Ok(outcome());
    announcements.recording = () =>
        const Err(PaymentAnnouncementUnavailableFailure());
    expect((await task().execute()).shouldRetry, isFalse);
    expect(
      logs.entries,
      contains((
        BackgroundLogLevel.warning,
        'Background observation failed: category=notification_persistence',
      )),
    );
  });

  test('missing observations still acknowledge the committed sync', () async {
    writer.operation = () async => Ok(outcome(incoming: null));
    expect((await task().execute()).shouldRetry, isFalse);
    expect(announcements.recorded.single.incomingTxids, isNull);
  });

  test(
    'failure uses writer stamp B, not admission A; repair C re-enables',
    () async {
      writer.operation = () async {
        // A concurrent foreground write advances storage after admission A
        // and before this writer acquires ownership and fails on B.
        revisions.revision = 2;
        return Err(BackgroundSyncNeedsRepairFailure(stamp(2)));
      };
      await task().execute();
      await task().execute();
      expect(writer.allowInitialScan, hasLength(1));
      revisions.revision = 3;
      writer.operation = () async => Ok(outcome());
      await task().execute();
      expect(writer.allowInitialScan, hasLength(2));
    },
  );

  test('lost Bitcoin claim stops admission of Liquid too', () async {
    final liquid = WalletKey(id: 'liquid', network: LiquidNetwork.testnet);
    writer.operation = () async {
      if (writer.allowInitialScan.length > 1) {
        return Ok(
          BackgroundSyncOutcome(
            revision: WalletRevision(key: liquid, generation: 1, revision: 2),
            incomingTxids: const [],
            completedAt: DateTime.utc(2026),
          ),
        );
      }
      final competing = _ok(
        SqliteWalletSyncJobQueueRepository.openExisting(
          '${directory.path}/queue',
          clock: () => DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
      );
      try {
        final claims = _ok(
          await competing.reconcileAndClaim([
            stamp(1),
          ], chain: WalletSyncChain.bitcoin),
        );
        expect(claims, hasLength(1));
      } finally {
        await competing.close();
      }
      return Ok(outcome());
    };
    expect((await task(keys: [key, liquid]).execute()).shouldRetry, isTrue);
    expect(writer.allowInitialScan, [false]);
  });

  for (final (failure, retried) in [
    (const PaymentAnnouncementDeniedFailure(), false),
    (const PaymentAnnouncementUnavailableFailure(), true),
  ]) {
    test('a ${failure.runtimeType} delivery retries=$retried', () async {
      writer.operation = () async => Ok(outcome());
      announcements.delivery = Err(failure);

      final result = await task().execute();

      expect(result.shouldRetry, retried);
      // Recorded after the queue settled the committed sync.
      expect(announcements.recorded.single.revision, stamp(2));
    });
  }

  test('operation exceptions log a fixed category and request retry', () async {
    writer.operation = () => throw Exception('private connection detail');
    expect((await task().execute()).shouldRetry, isTrue);
    expect(
      logs.entries.map((e) => e.$2),
      contains('Background job retry: category=operation_exception'),
    );
    expect(logs.entries.any((e) => e.$2.contains('private')), isFalse);
  });

  test('zero admission budget does not start a writer', () async {
    await task(budget: Duration.zero).execute();
    expect(writer.allowInitialScan, isEmpty);
    final messages = (await log.readLogs()).map((row) => row.split('\t')[2]);
    expect(
      messages.where(
        (message) =>
            message.startsWith('Background admission stopped reason=budget'),
      ),
      hasLength(2),
    );
  });

  test(
    'budget does not cancel an admitted writer or start the next wallet',
    () async {
      final pending =
          Completer<Result<BackgroundSyncOutcome, BackgroundSyncFailure>>();
      final started = Completer<void>();
      writer.operation = () {
        started.complete();
        return pending.future;
      };
      final clock = _Clock();
      var finished = false;
      final running =
          task(
            budget: const Duration(seconds: 10),
            keys: [key, second],
          ).execute(clock: clock).then((value) {
            finished = true;
            return value;
          });
      await started.future;
      clock.elapsedValue = const Duration(seconds: 20);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      pending.complete(Ok(outcome()));
      await running;
      expect(writer.allowInitialScan, [false]);
    },
  );
}

final class _Clock implements Stopwatch {
  Duration elapsedValue = Duration.zero;
  @override
  Duration get elapsed => elapsedValue;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Writer implements BackgroundWalletSyncPort {
  final List<bool> allowInitialScan = [];
  final List<bool> discover = [];
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> Function()?
  operation;
  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
    required bool discover,
  }) {
    this.allowInitialScan.add(allowInitialScan);
    this.discover.add(discover);
    final run = operation;
    if (run == null) throw StateError('No fake operation');
    return run();
  }
}

final class _Revisions implements WalletRevisionReaderPort {
  int revision = 1;
  WalletKey? unavailable;
  bool pending = true;
  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async => key == unavailable && !pending
      ? const Err(TransactionSyncNotFoundFailure())
      : Ok(
          WalletRevisionState(
            stamp: WalletRevision(key: key, generation: 1, revision: revision),
            lifecycle: key == unavailable
                ? WalletLifecycle.pendingWrite
                : WalletLifecycle.active,
          ),
        );
  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class _Announcements implements PaymentAnnouncementPort {
  final List<BackgroundSyncOutcome> recorded = [];
  Result<void, PaymentAnnouncementFailure> Function() recording = () =>
      const Ok(null);
  Result<void, PaymentAnnouncementFailure> delivery = const Ok(null);
  int deliveries = 0;

  @override
  Future<Result<void, PaymentAnnouncementFailure>> record(
    BackgroundSyncOutcome outcome,
  ) async {
    recorded.add(outcome);
    return recording();
  }

  @override
  Future<Result<void, PaymentAnnouncementFailure>> deliverPending() async {
    deliveries++;
    return delivery;
  }
}

final class _Logs implements BackgroundTaskLoggerPort {
  final List<(BackgroundLogLevel, String)> entries = [];

  @override
  Future<void> flush() async {}
  @override
  void write(BackgroundLogLevel level, String message) {
    entries.add((level, message));
    LoggerBackgroundTaskLogger(log).write(level, message);
  }
}

T _ok<T>(Result<T, BackgroundTasksFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => fail('$failure'),
};
