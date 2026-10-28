import 'dart:async';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

final class _Gateway implements LocalNotificationGateway {
  final shown = <LocalNotification>[];
  bool enabled = true;

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(true);

  @override
  Future<Result<bool, NotificationsFailure>> isEnabled() async => Ok(enabled);

  @override
  Future<Result<void, NotificationsFailure>> openSystemSettings() async =>
      const Ok(null);

  @override
  Future<Result<void, NotificationsFailure>> initialize(
    NotificationResponseCallback onResponse,
  ) async => const Ok(null);

  @override
  Future<Result<void, NotificationsFailure>> show(
    LocalNotification notification, {
    required int platformId,
  }) async {
    shown.add(notification);
    return const Ok(null);
  }
}

WalletTransaction _transaction(
  String txid,
  TransactionDirection? direction, {
  bool? selfTransfer,
}) => WalletTransaction(
  txid: txid,
  amountSats: 1,
  direction: direction,
  selfTransfer: selfTransfer,
  position: const UnknownPosition(),
);

WalletTransactionSyncOutcome _outcome(
  WalletNetworkKey key,
  List<WalletTransaction> transactions,
) => WalletTransactionSyncOutcome(
  WalletTransactionSnapshot(
    key: key,
    revision: 1,
    contentFingerprint: 'fingerprint',
    transactions: transactions,
    observedAt: DateTime.utc(2026, 1, 1),
    lastSuccessfulSyncAt: DateTime.utc(2026, 1, 1),
    sourceKind: 'fake',
    capabilities: const {},
    sourceTip: null,
    complete: true,
    evidenceLevel: WalletEvidenceLevel.localSourceState,
  ),
);

/// What the foreground recorded for [key]: the wallet's baseline.
Future<void> _baseline(
  SqliteNotificationOutbox outbox,
  WalletNetworkKey key, [
  List<String> txids = const [],
]) async {
  final result = await outbox
      .recordObserved(WalletPaymentNotificationIdentity.topicId(key), [
        for (final txid in txids)
          WalletPaymentNotificationIdentity.event(
            key,
            txid,
            observedAt: DateTime.utc(2026, 1, 1),
          ),
      ]);
  expect(result, isA<Ok>());
}

void main() {
  test(
    'reconciles the complete snapshot, filters precisely, and is idempotent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gateway = _Gateway();
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      final key = const WalletNetworkKey('wallet', 'bitcoin', 'testnet');
      final all = [
        _transaction('incoming', TransactionDirection.incoming),
        _transaction('self', TransactionDirection.incoming, selfTransfer: true),
        _transaction('outgoing', TransactionDirection.outgoing),
        _transaction('unknown', null),
      ];
      await _baseline(outbox, key, ['incoming', 'self', 'outgoing', 'unknown']);
      final job = WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async => Ok(_outcome(key, all)),
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [job],
        copy: (count, chain) => (
          title: 'Payment received!',
          body: '$count $chain transaction received',
        ),
      );

      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.success,
      );
      expect(gateway.shown, hasLength(0));
      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.success,
      );
      expect(gateway.shown, hasLength(0));

      final second = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          WalletTransactionSyncBackgroundJob(
            key: job.key,
            synchronize: () async => Ok(
              _outcome(key, [
                ...all,
                _transaction('new', TransactionDirection.incoming),
              ]),
            ),
          ),
        ],
        copy: (count, chain) => (
          title: 'Payment received!',
          body: '$count $chain transaction received',
        ),
      );
      await second.execute(chain: 'bitcoin');
      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single.body, '1 bitcoin transaction received');
      outbox.dispose();
      final reopenedOutbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      addTearDown(reopenedOutbox.dispose);
      final reopened = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(
          gateway: gateway,
          outbox: reopenedOutbox,
        ),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          WalletTransactionSyncBackgroundJob(
            key: job.key,
            synchronize: () async => Ok(
              _outcome(key, [
                ...all,
                _transaction('new', TransactionDirection.incoming),
              ]),
            ),
          ),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      );
      await reopened.execute(chain: 'bitcoin');
      expect(gateway.shown, hasLength(1));
    },
  );

  test(
    'continues after one wallet fails and only runs selected chains',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      addTearDown(() => directory.delete(recursive: true));
      final gateway = _Gateway();
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/n.sqlite',
      );
      final calls = <String>[];
      WalletTransactionSyncBackgroundJob job(
        String chain,
        String id,
        bool fail,
      ) => WalletTransactionSyncBackgroundJob(
        key: WalletNetworkKey(id, chain, 'testnet'),
        synchronize: () async {
          calls.add(id);
          if (fail) {
            return const Err(SourceFailure(SourceFailureReason.unavailable));
          }
          final key = WalletNetworkKey(id, chain, 'testnet');
          return Ok(
            _outcome(key, [_transaction(id, TransactionDirection.incoming)]),
          );
        },
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          job('bitcoin', 'bad', true),
          job('bitcoin', 'good', false),
          job('other', 'skip', false),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      );

      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.retry,
      );
      expect(calls, ['bad', 'good']);
      expect(gateway.shown, hasLength(0));
    },
  );

  test(
    'aggregates new transactions across wallets for the selected chain',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      final gateway = _Gateway();
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/notifications.sqlite',
      );
      addTearDown(() async {
        outbox.dispose();
        await directory.delete(recursive: true);
      });
      WalletTransactionSyncBackgroundJob job(String wallet, List<String> ids) {
        final key = WalletNetworkKey(wallet, 'liquid', 'testnet');
        return WalletTransactionSyncBackgroundJob(
          key: key,
          synchronize: () async => Ok(
            _outcome(
              key,
              ids
                  .map((id) => _transaction(id, TransactionDirection.incoming))
                  .toList(),
            ),
          ),
        );
      }

      await _baseline(
        outbox,
        const WalletNetworkKey('one', 'liquid', 'testnet'),
        ['one'],
      );
      await _baseline(
        outbox,
        const WalletNetworkKey('two', 'liquid', 'testnet'),
        ['two'],
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          job('one', ['one']),
          job('two', ['two']),
        ],
        copy: (count, chain) => (
          title: 'Payment received!',
          body: count == 1
              ? '1 $chain transaction received'
              : '$count transactions received',
        ),
      );
      await task.execute(chain: 'liquid');
      expect(gateway.shown, isEmpty);

      final second = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          job('one', ['one', 'new-one']),
          job('two', ['two']),
        ],
        copy: (count, chain) => (
          title: 'Payment received!',
          body: count == 1
              ? '1 $chain transaction received'
              : '$count transactions received',
        ),
      );
      await second.execute(chain: 'liquid');
      expect(gateway.shown, hasLength(1));
      expect(gateway.shown.single.body, '1 liquid transaction received');

      final third = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          job('one', ['one', 'new-one', 'new-two']),
          job('two', ['two', 'new-three']),
        ],
        copy: (count, chain) => (
          title: 'Payment received!',
          body: count == 1
              ? '1 $chain transaction received'
              : '$count transactions received',
        ),
      );
      await third.execute(chain: 'liquid');
      expect(gateway.shown, hasLength(2));
      expect(gateway.shown.last.body, '2 transactions received');
      await third.execute(chain: 'liquid');
      expect(gateway.shown, hasLength(2));
    },
  );

  test('a storage failure is retried, not abandoned', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    addTearDown(() => directory.delete(recursive: true));
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(
        gateway: _Gateway(),
        outbox: SqliteNotificationOutbox(
          databasePath: '${directory.path}/n.sqlite',
        ),
      ),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: const WalletNetworkKey('wallet', 'bitcoin', 'testnet'),
          synchronize: () async => const Err(SourceStorageFailure()),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
    );

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.retry,
    );
  });

  test('does not execute jobs from the other requested chain', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    addTearDown(() async {
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final calls = <String>[];
    WalletTransactionSyncBackgroundJob job(String chain) =>
        WalletTransactionSyncBackgroundJob(
          key: WalletNetworkKey(chain, chain, 'testnet'),
          synchronize: () async {
            calls.add(chain);
            final key = WalletNetworkKey(chain, chain, 'testnet');
            return Ok(_outcome(key, const []));
          },
        );
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/q.sqlite',
      ),
      jobs: [job('bitcoin'), job('liquid')],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
    );
    await task.execute(chain: 'bitcoin');
    expect(calls, ['bitcoin']);
    calls.clear();
    await task.execute(chain: 'liquid');
    expect(calls, ['liquid']);
    calls.clear();
    expect(
      (await task.execute(chain: 'unknown')).status,
      BackgroundTaskExecutionStatus.permanentFailure,
    );
    expect(calls, isEmpty);
  });

  test('rejects a non-positive concurrency limit', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    addTearDown(() async {
      outbox.dispose();
      await directory.delete(recursive: true);
    });

    expect(
      () => WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: const [],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        maxConcurrentJobs: 0,
      ),
      throwsArgumentError,
    );
  });

  test('never exceeds the configured concurrency limit', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    addTearDown(() async {
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    var active = 0;
    var maximum = 0;
    final started = List.generate(5, (_) => Completer<void>());
    final release = List.generate(5, (_) => Completer<void>());
    final jobs = List.generate(5, (index) {
      final key = WalletNetworkKey('wallet-$index', 'bitcoin', 'testnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          active++;
          maximum = active > maximum ? active : maximum;
          started[index].complete();
          await release[index].future;
          active--;
          return Ok(_outcome(key, const []));
        },
      );
    });
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/q.sqlite',
      ),
      jobs: jobs,
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      maxConcurrentJobs: 2,
      maxJobsPerRun: 5,
    );
    final execution = task.execute(chain: 'bitcoin');
    await Future.wait([started[0].future, started[1].future]);
    expect(active, 2);
    expect(started[2].isCompleted, isFalse);
    release[0].complete();
    await started[2].future;
    release[1].complete();
    await started[3].future;
    release[2].complete();
    await started[4].future;
    release[3].complete();
    release[4].complete();
    await execution;
    expect(maximum, 2);
  });

  test(
    'attempts remaining wallets after thrown and returned failures',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/n.sqlite',
      );
      addTearDown(() async {
        outbox.dispose();
        await directory.delete(recursive: true);
      });
      final calls = <String>[];
      WalletTransactionSyncBackgroundJob job(
        String id,
        Future<
          Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>
        >
        Function()
        operation,
      ) => WalletTransactionSyncBackgroundJob(
        key: WalletNetworkKey(id, 'bitcoin', 'testnet'),
        synchronize: () async {
          calls.add(id);
          return operation();
        },
      );
      final successfulKey = const WalletNetworkKey(
        'successful',
        'bitcoin',
        'testnet',
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
        queue: SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/q.sqlite',
        ),
        jobs: [
          job('thrown', () async => throw StateError('failed')),
          job(
            'returned',
            () async =>
                const Err(SourceFailure(SourceFailureReason.unavailable)),
          ),
          job('successful', () async => Ok(_outcome(successfulKey, const []))),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        maxConcurrentJobs: 2,
        maxJobsPerRun: 3,
      );

      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.retry,
      );
      expect(calls, ['thrown', 'returned', 'successful']);
    },
  );

  test('logs only aggregate counts and fixed failure categories', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final messages = <String>[];
    final sink = _Sink(messages);
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
      logSink: sink,
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    const walletId = 'private-wallet-id';
    const failureText = 'private.server.invalid transport secret';
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: const WalletNetworkKey(walletId, 'bitcoin', 'testnet'),
          synchronize: () => throw StateError(failureText),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: sink,
    );

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.retry,
    );
    final logs = messages.join('\n');
    expect(logs, contains('chain=bitcoin'));
    expect(logs, contains('claimed=1'));
    expect(logs, contains('category=operation_exception'));
    expect(logs, isNot(contains(walletId)));
    expect(logs, isNot(contains(failureText)));
  });

  test(
    'logs a retryable failure with its category and the batch timing',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/n.sqlite',
      );
      final messages = <String>[];
      final sink = _Sink(messages);
      final queue = SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/q.sqlite',
        logSink: sink,
      );
      addTearDown(() async {
        await queue.close();
        outbox.dispose();
        await directory.delete(recursive: true);
      });
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
        queue: queue,
        jobs: [
          WalletTransactionSyncBackgroundJob(
            key: const WalletNetworkKey('wallet', 'bitcoin', 'testnet'),
            synchronize: () async =>
                const Err(SourceFailure(SourceFailureReason.unavailable)),
          ),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        logSink: sink,
      );

      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.retry,
      );
      expect(
        messages,
        contains(
          'Wallet sync retryable failure chain=bitcoin '
          'category=SourceFailure.unavailable',
        ),
      );
      expect(
        messages.last,
        matches(
          RegExp(
            r'^Wallet sync queue completion: chain=bitcoin claimed=1 '
            r'succeeded=0 retried=1 permanent=0 new_incoming=0 elapsed_ms=\d+$',
          ),
        ),
      );
    },
  );

  test('disabled notifications neither fail the task nor replay', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final gateway = _Gateway()..enabled = false;
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final messages = <String>[];
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final key = const WalletNetworkKey('wallet', 'bitcoin', 'testnet');
    await _baseline(outbox, key);
    var incoming = <WalletTransaction>[];
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: key,
          synchronize: () async => Ok(_outcome(key, incoming)),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: _Sink(messages),
    );
    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
    incoming = [_transaction('paid', TransactionDirection.incoming)];

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(gateway.shown, isEmpty);
    expect(
      messages,
      contains(
        'Wallet sync notification failure stage=deliver '
        'category=permission_denied',
      ),
    );

    // Granted later: the payment seen while hidden is not replayed.
    gateway.enabled = true;
    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(gateway.shown, isEmpty);
  });

  test(
    'a wallet without a foreground baseline is synced, not announced',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background_tasks',
      );
      final gateway = _Gateway();
      final outbox = SqliteNotificationOutbox(
        databasePath: '${directory.path}/n.sqlite',
      );
      final queue = SqliteWalletSyncJobQueue(
        databasePath: '${directory.path}/q.sqlite',
      );
      final messages = <String>[];
      addTearDown(() async {
        await queue.close();
        outbox.dispose();
        await directory.delete(recursive: true);
      });
      final key = const WalletNetworkKey('restored', 'bitcoin', 'mainnet');
      var synced = 0;
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: queue,
        jobs: [
          WalletTransactionSyncBackgroundJob(
            key: key,
            synchronize: () async {
              synced++;
              return Ok(
                _outcome(key, [
                  _transaction('history', TransactionDirection.incoming),
                ]),
              );
            },
          ),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        logSink: _Sink(messages),
      );

      // Twice: the history is never taken as a silent baseline either.
      for (var i = 0; i < 2; i++) {
        expect(
          (await task.execute(chain: 'bitcoin')).status,
          BackgroundTaskExecutionStatus.success,
        );
      }
      expect(synced, 2);
      expect(gateway.shown, isEmpty);
      expect(
        messages,
        contains(
          'Wallet sync notifications skipped: chain=bitcoin '
          'wallets_without_baseline=1',
        ),
      );

      // The foreground records the history, then a payment arrives.
      await _baseline(outbox, key, ['history']);
      final later = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
        queue: queue,
        jobs: [
          WalletTransactionSyncBackgroundJob(
            key: key,
            synchronize: () async => Ok(
              _outcome(key, [
                _transaction('history', TransactionDirection.incoming),
                _transaction(
                  'paid-while-closed',
                  TransactionDirection.incoming,
                ),
              ]),
            ),
          ),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        logSink: _Sink(messages),
      );
      expect(
        (await later.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.success,
      );
      expect(gateway.shown, hasLength(1));
    },
  );

  test('a wallet awaiting its first scan is skipped, not retried', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    final messages = <String>[];
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: const WalletNetworkKey('fresh', 'bitcoin', 'mainnet'),
          synchronize: () async => const Err(InitialScanRequiredFailure()),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: _Sink(messages),
    );

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(
      messages,
      contains(
        'Wallet sync skipped: chain=bitcoin '
        'reason=initial_scan_in_foreground',
      ),
    );

    // No backoff: once the app has scanned it, the very next run syncs it.
    expect(
      await queue.reconcileAndClaim([
        (
          key: const WalletNetworkKey('fresh', 'bitcoin', 'mainnet'),
          revision: 'legacy-electrum-v1',
        ),
      ], chain: 'bitcoin'),
      hasLength(1),
    );
  });

  test('a run stops starting wallets once its budget is spent', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    final messages = <String>[];
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final started = <String>[];
    WalletTransactionSyncBackgroundJob job(String id) {
      final key = WalletNetworkKey(id, 'bitcoin', 'mainnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          started.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 80));
          return Ok(_outcome(key, const []));
        },
      );
    }

    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [job('a'), job('b')],
      maxConcurrentJobs: 1,
      runBudget: const Duration(milliseconds: 20),
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: _Sink(messages),
    );

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(started, hasLength(1));
    expect(messages, contains('Wallet sync run budget reached: chain=bitcoin'));

    // The wallet left over is first in line next run.
    final next = await queue.reconcileAndClaim([
      (
        key: WalletNetworkKey(
          started.single == 'a' ? 'b' : 'a',
          'bitcoin',
          'mainnet',
        ),
        revision: 'legacy-electrum-v1',
      ),
    ], chain: 'bitcoin');
    expect(next, hasLength(1));
  });

  test('a wallet waiting for a worker is not claimed', () async {
    // If the platform stops the run while the first wallet syncs, the second
    // must keep its turn: no attempt counted, no lease held.
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final started = <String>[];
    final firstStarted = Completer<void>();
    final release = Completer<void>();
    WalletTransactionSyncBackgroundJob job(String id) {
      final key = WalletNetworkKey(id, 'bitcoin', 'mainnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          started.add(id);
          if (!firstStarted.isCompleted) firstStarted.complete();
          await release.future;
          return Ok(_outcome(key, const []));
        },
      );
    }

    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [job('a'), job('b')],
      maxConcurrentJobs: 1,
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
    );
    final execution = task.execute(chain: 'bitcoin');
    await firstStarted.future;

    final waiting = started.single == 'a' ? 'b' : 'a';
    final claimable = await queue.reconcileAndClaim([
      (
        key: WalletNetworkKey(waiting, 'bitcoin', 'mainnet'),
        revision: 'legacy-electrum-v1',
      ),
    ], chain: 'bitcoin');
    expect(claimable, hasLength(1));
    release.complete();
    await execution;
  });

  test('a run whose startup used the budget starts no wallet', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final started = <String>[];
    WalletTransactionSyncBackgroundJob job(String id, String chain) {
      final key = WalletNetworkKey(id, chain, 'mainnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          started.add(id);
          return Ok(_outcome(key, const []));
        },
      );
    }

    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [job('a', 'bitcoin'), job('b', 'liquid')],
      runBudget: const Duration(milliseconds: 20),
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
    );
    final bootstrap = Stopwatch()..start();
    await Future<void>.delayed(const Duration(milliseconds: 40));

    await task.executeAll(clock: bootstrap);

    expect(started, isEmpty);
  });

  test('a long failure name is logged as a short fixed label', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    final messages = <String>[];
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: const WalletNetworkKey('w', 'bitcoin', 'mainnet'),
          synchronize: () async =>
              const Err(WalletSourceStateIncompatibleFailure()),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: _Sink(messages),
    );

    await task.execute(chain: 'bitcoin');

    // The support log redacts runs of 32 or more letters as secrets.
    expect(
      messages,
      contains(
        'Wallet sync permanent failure chain=bitcoin '
        'category=source_state_incompatible',
      ),
    );
  });

  test('one run syncs both chains under one budget', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final gateway = _Gateway();
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final synced = <String>[];
    WalletTransactionSyncBackgroundJob job(String chain) {
      final key = WalletNetworkKey('w', chain, 'testnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          synced.add(chain);
          return Ok(_outcome(key, const []));
        },
      );
    }

    WalletTransactionSyncBackgroundTask task({Duration? budget}) =>
        WalletTransactionSyncBackgroundTask(
          notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
          queue: queue,
          jobs: [job('bitcoin'), job('liquid')],
          runBudget: budget,
          copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        );

    expect(
      (await task().executeAll()).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(synced, ['bitcoin', 'liquid']);

    synced.clear();
    expect(
      (await task(budget: Duration.zero).executeAll()).status,
      BackgroundTaskExecutionStatus.success,
    );
    expect(synced, isEmpty);
  });

  test('bitcoin leaves liquid half of the budget', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final synced = <String>[];
    WalletTransactionSyncBackgroundJob job(String id, String chain) {
      final key = WalletNetworkKey(id, chain, 'testnet');
      return WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          synced.add(id);
          await Future<void>.delayed(const Duration(milliseconds: 150));
          return Ok(_outcome(key, const []));
        },
      );
    }

    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [job('b1', 'bitcoin'), job('b2', 'bitcoin'), job('l1', 'liquid')],
      maxConcurrentJobs: 1,
      runBudget: const Duration(milliseconds: 250),
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
    );

    await task.executeAll();

    // Without the split, the second bitcoin wallet would take the rest.
    expect(synced, ['b1', 'l1']);
  });

  test('logging sink failure cannot alter a successful batch', () async {
    final directory = await Directory.systemTemp.createTemp('background_tasks');
    final outbox = SqliteNotificationOutbox(
      databasePath: '${directory.path}/n.sqlite',
    );
    final queue = SqliteWalletSyncJobQueue(
      databasePath: '${directory.path}/q.sqlite',
      logSink: _ThrowingSink(),
    );
    addTearDown(() async {
      await queue.close();
      outbox.dispose();
      await directory.delete(recursive: true);
    });
    final key = const WalletNetworkKey('wallet', 'bitcoin', 'testnet');
    final task = WalletTransactionSyncBackgroundTask(
      notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
      queue: queue,
      jobs: [
        WalletTransactionSyncBackgroundJob(
          key: key,
          synchronize: () async => Ok(_outcome(key, const [])),
        ),
      ],
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      logSink: _ThrowingSink(),
    );

    expect(
      (await task.execute(chain: 'bitcoin')).status,
      BackgroundTaskExecutionStatus.success,
    );
  });
}

final class _Sink implements WalletSyncLogSink {
  final List<String> messages;

  _Sink(this.messages);

  @override
  void write(WalletSyncLogLevel level, String message) => messages.add(message);
}

final class _ThrowingSink implements WalletSyncLogSink {
  @override
  void write(WalletSyncLogLevel level, String message) {
    throw StateError('logger unavailable');
  }
}
