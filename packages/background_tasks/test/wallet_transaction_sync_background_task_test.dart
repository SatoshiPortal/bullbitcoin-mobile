import 'dart:async';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  late Directory directory;
  late SqliteNotificationOutbox outbox;
  late SqliteWalletSyncJobQueue queue;
  late _Writer writer;
  late _Revisions revisions;
  late _Gateway gateway;
  late NotificationsFacade notifications;
  late _Logs logs;
  final key = WalletKey(id: 'wallet', network: BitcoinNetwork.testnet);
  final second = WalletKey(id: 'second', network: BitcoinNetwork.testnet);
  WalletRevision stamp(int revision) =>
      WalletRevision(key: key, generation: 1, revision: revision);
  BackgroundSyncOutcome outcome({
    bool foreground = false,
    List<String> incoming = const ['old', 'new'],
    List<String> discovered = const [],
  }) => BackgroundSyncOutcome(
    revision: stamp(2),
    incomingTxids: incoming,
    discoveredTxids: discovered,
    completedAt: DateTime.utc(2026),
    completedInForeground: foreground,
  );
  WalletTransactionSyncBackgroundTask task({
    Duration? budget,
    List<WalletKey>? keys,
  }) => WalletTransactionSyncBackgroundTask(
    writer: writer,
    revisions: revisions,
    keys: keys ?? [key],
    queue: queue,
    notifications: notifications,
    copy: (count, chain) => (title: 'Payments', body: '$count'),
    runBudget: budget,
    logSink: logs,
  );
  Future<Result<void, NotificationsFailure>> baseline() =>
      WalletPaymentObservationAdapter(notifications).recordCompletion(
        outcome(foreground: true, incoming: ['old'], discovered: ['old']),
      );
  setUp(() {
    directory = Directory.systemTemp.createTempSync('background-task-');
    outbox = SqliteNotificationOutbox(databasePath: '${directory.path}/outbox');
    queue = SqliteWalletSyncJobQueue(databasePath: '${directory.path}/queue');
    writer = _Writer();
    logs = _Logs();
    revisions = _Revisions();
    gateway = _Gateway();
    notifications = NotificationsFacade(gateway: gateway, outbox: outbox);
  });
  tearDown(() async {
    await queue.close();
    outbox.dispose();
    directory.deleteSync(recursive: true);
  });

  test(
    'background commit replay announces payment with no new discovery',
    () async {
      await baseline();
      // Simulates a prior native commit followed by interruption before outbox.
      writer.operation = () async => Ok(outcome(discovered: []));
      expect((await task().executeAll()).shouldRetry, isFalse);
      expect(writer.allowInitialScan, [false]);
      expect(
        logs.entries.any(
          (e) =>
              e.$1 == WalletSyncLogLevel.fine && e.$2.contains('job finished'),
        ),
        isTrue,
      );
      expect(logs.entries.any((e) => e.$2.contains(key.id)), isFalse);
      expect(gateway.shown, hasLength(1));
      await task().executeAll();
      expect(gateway.shown, hasLength(1));
    },
  );

  test('foreground re-sync does not mark background discoveries seen', () async {
    await baseline();
    // The payment was discovered in background. Foreground sees it on its
    // subsequent sync, but discovers only another payment itself.
    writer.operation = () async => Ok(
      outcome(
        foreground: true,
        incoming: ['old', 'background', 'foreground'],
        discovered: ['foreground'],
      ),
    );
    await task().executeAll();
    expect(gateway.shown.single.body, '1');
    final db = sqlite3.open('${directory.path}/outbox');
    try {
      final rows = db.select(
        'SELECT event_id, seen_at FROM notification_outbox WHERE topic_id IS NOT NULL',
      );
      final seen = {for (final row in rows) row['event_id']: row['seen_at']};
      expect(
        seen[WalletPaymentNotificationIdentity.eventId(key, 'background')],
        isNull,
      );
      expect(
        seen[WalletPaymentNotificationIdentity.eventId(key, 'foreground')],
        isNotNull,
      );
    } finally {
      db.dispose();
    }
  });

  test(
    'initial foreground baseline is silent without marking old history seen',
    () async {
      writer.operation = () async =>
          Ok(outcome(foreground: true, discovered: ['new']));
      await task().executeAll();
      expect(gateway.shown, isEmpty);
      final db = sqlite3.open('${directory.path}/outbox');
      try {
        expect(
          db.select(
            'SELECT seen_at FROM notification_outbox WHERE event_id=?',
            [WalletPaymentNotificationIdentity.eventId(key, 'old')],
          ).single['seen_at'],
          isNull,
        );
      } finally {
        db.dispose();
      }
    },
  );

  test(
    'failure uses writer stamp B, not admission A; repair C re-enables',
    () async {
      writer.operation = () async {
        // A concurrent foreground write advances storage after admission A
        // and before this writer acquires ownership and fails on B.
        revisions.revision = 2;
        return Err(BackgroundSyncNeedsRepairFailure(stamp(2)));
      };
      await task().executeAll();
      await task().executeAll();
      expect(writer.allowInitialScan, hasLength(1));
      revisions.revision = 3;
      writer.operation = () async => Ok(outcome());
      await task().executeAll();
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
            discoveredTxids: const [],
            completedAt: DateTime.utc(2026),
            completedInForeground: false,
          ),
        );
      }
      final competing = SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/queue',
        clock: () => DateTime.now().toUtc().add(const Duration(hours: 1)),
      );
      try {
        final claims = await competing.reconcileAndClaim([
          stamp(1),
        ], chain: WalletSyncChain.bitcoin);
        expect(claims, hasLength(1));
      } finally {
        await competing.close();
      }
      return Ok(outcome());
    };
    expect((await task(keys: [key, liquid]).executeAll()).shouldRetry, isTrue);
    expect(writer.allowInitialScan, [false]);
  });

  test('zero admission budget does not start a writer', () async {
    await task(budget: Duration.zero).executeAll();
    expect(writer.allowInitialScan, isEmpty);
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
          ).execute(chain: WalletSyncChain.bitcoin, clock: clock).then((value) {
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

  test(
    'completion visibility, not admission visibility, controls seen',
    () async {
      for (final foregroundAtEnd in [false, true]) {
        await baseline();
        var visible = !foregroundAtEnd;
        writer.operation = () async {
          visible = foregroundAtEnd;
          return Ok(
            outcome(
              foreground: visible,
              incoming: ['old', 'change-$foregroundAtEnd'],
              discovered: ['change-$foregroundAtEnd'],
            ),
          );
        };
        await task().executeAll();
      }
      expect(gateway.shown, hasLength(1));
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

final class _Writer implements BackgroundWalletSync {
  final List<bool> allowInitialScan = [];
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> Function()?
  operation;
  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
  }) {
    this.allowInitialScan.add(allowInitialScan);
    final run = operation;
    if (run == null) throw StateError('No fake operation');
    return run();
  }
}

final class _Revisions implements WalletRevisionReader {
  int revision = 1;
  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async => Ok(
    WalletRevisionState(
      stamp: WalletRevision(key: key, generation: 1, revision: revision),
      lifecycle: WalletLifecycle.active,
    ),
  );
  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}

final class _Gateway implements LocalNotificationGateway {
  final List<LocalNotification> shown = [];
  @override
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  ) async => const Ok(null);
  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async =>
      const Ok(true);
  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(true);
  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);
  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    shown.add(notification);
    return const Ok(null);
  }
}

final class _Logs implements WalletSyncLogSink {
  final List<(WalletSyncLogLevel, String)> entries = [];
  @override
  void write(WalletSyncLogLevel level, String message) =>
      entries.add((level, message));
}
