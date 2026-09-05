import 'dart:async';
import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

final class _Gateway implements LocalNotificationGateway {
  final shown = <LocalNotification>[];

  @override
  Future<Result<bool, NotificationsFailure>> requestPermission() async =>
      const Ok(true);

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
      final job = WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async => Ok(_outcome(key, all)),
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
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

      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: gateway, outbox: outbox),
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
      jobs: jobs,
      copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
      maxConcurrentJobs: 2,
    );
    final execution = task.execute(chain: 'bitcoin');
    await Future.wait([started[0].future, started[1].future]);
    expect(active, 2);
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
    'starts the next wallet when a slot frees before an earlier wallet',
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
      final firstRelease = Completer<void>();
      final secondRelease = Completer<void>();
      final firstStarted = Completer<void>();
      final secondStarted = Completer<void>();
      final thirdStarted = Completer<void>();
      final started = <String>[];
      final firstKey = const WalletNetworkKey('first', 'bitcoin', 'testnet');
      final secondKey = const WalletNetworkKey('second', 'bitcoin', 'testnet');
      final thirdKey = const WalletNetworkKey('third', 'bitcoin', 'testnet');
      WalletTransactionSyncBackgroundJob job(
        WalletNetworkKey key,
        Future<void>? wait,
        Completer<void> didStart,
      ) => WalletTransactionSyncBackgroundJob(
        key: key,
        synchronize: () async {
          started.add(key.walletId);
          didStart.complete();
          if (wait != null) await wait;
          return Ok(_outcome(key, const []));
        },
      );
      final task = WalletTransactionSyncBackgroundTask(
        notifications: NotificationsFacade(gateway: _Gateway(), outbox: outbox),
        jobs: [
          job(firstKey, firstRelease.future, firstStarted),
          job(secondKey, secondRelease.future, secondStarted),
          job(thirdKey, null, thirdStarted),
        ],
        copy: (_, _) => (title: 'Incoming', body: 'Payment received'),
        maxConcurrentJobs: 2,
      );
      final execution = task.execute(chain: 'bitcoin');
      await Future.wait([firstStarted.future, secondStarted.future]);
      expect(started, ['first', 'second']);
      secondRelease.complete();
      await thirdStarted.future;
      expect(started, ['first', 'second', 'third']);
      expect(firstRelease.isCompleted, isFalse);
      firstRelease.complete();
      await execution;
    },
  );

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
      );

      expect(
        (await task.execute(chain: 'bitcoin')).status,
        BackgroundTaskExecutionStatus.retry,
      );
      expect(calls, ['thrown', 'returned', 'successful']);
    },
  );
}
