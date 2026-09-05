import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:wallet_transaction_sync/wallet_transaction_sync.dart';

import 'background_task_execution_result.dart';

typedef SyncJobOperation =
    Future<Result<WalletTransactionSyncOutcome, WalletTransactionSyncFailure>>
    Function();
typedef NotificationCopy = ({String title, String body});
typedef NotificationCopyBuilder =
    NotificationCopy Function(int count, String chain);

final class WalletTransactionSyncBackgroundJob {
  final WalletNetworkKey key;
  final SyncJobOperation synchronize;

  const WalletTransactionSyncBackgroundJob({
    required this.key,
    required this.synchronize,
  });
}

final class WalletTransactionSyncBackgroundTask {
  final NotificationsFacade notifications;
  final List<WalletTransactionSyncBackgroundJob> jobs;
  final NotificationCopyBuilder copy;

  const WalletTransactionSyncBackgroundTask({
    required this.notifications,
    required this.jobs,
    required this.copy,
  });

  Future<BackgroundTaskExecutionResult> execute({required String chain}) async {
    if (chain != 'bitcoin' && chain != 'liquid') {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    var retry = false;
    var permanent = false;
    final observations = <NotificationTopicObservation>[];
    for (final job in jobs) {
      if (job.key.chain != chain) continue;
      try {
        final sync = await job.synchronize();
        switch (sync) {
          case Err(:final failure):
            _classifySync(
              failure,
              onRetry: () => retry = true,
              onPermanent: () => permanent = true,
            );
          case Ok(:final value):
            final topic = _hash(
              'background-notifications-v1|${job.key.walletId}|'
              '${job.key.chain}|${job.key.network}',
            );
            final events = value.snapshot.transactions
                .where(
                  (transaction) =>
                      transaction.direction == TransactionDirection.incoming &&
                      transaction.selfTransfer != true,
                )
                .map(
                  (transaction) => LocalNotification(
                    eventId: _hash(
                      'background-notifications-v1|${job.key.walletId}|'
                      '${job.key.chain}|${job.key.network}|${transaction.txid}',
                    ),
                    title: '',
                    body: '',
                    destination: NotificationDestination.walletHome,
                    createdAt: value.snapshot.observedAt,
                  ),
                )
                .toList();
            observations.add(NotificationTopicObservation(topic, events));
        }
      } catch (_) {
        retry = true;
      }
    }
    if (observations.isNotEmpty) {
      final reconciled = await notifications.reconcileTopicsAndEnqueue(
        observations,
        (newEvents) {
          final eventIds = newEvents.map((event) => event.eventId).toList()
            ..sort();
          final text = copy(newEvents.length, chain);
          return LocalNotification(
            eventId: _hash(
              'background-notifications-v2|$chain|${eventIds.join('|')}',
            ),
            title: text.title,
            body: text.body,
            destination: NotificationDestination.walletHome,
            createdAt: newEvents
                .map((event) => event.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          );
        },
      );
      if (reconciled case Err(:final failure)) {
        _classifyNotification(
          failure,
          onRetry: () => retry = true,
          onPermanent: () => permanent = true,
        );
      }
    }
    try {
      final delivered = await notifications.deliverPending();
      if (delivered case Err(:final failure)) {
        _classifyNotification(
          failure,
          onRetry: () => retry = true,
          onPermanent: () => permanent = true,
        );
      }
    } catch (_) {
      retry = true;
    }
    if (retry) return const BackgroundTaskExecutionResult.retry();
    if (permanent) {
      return const BackgroundTaskExecutionResult.permanentFailure();
    }
    return const BackgroundTaskExecutionResult.success();
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static void _classifySync(
    WalletTransactionSyncFailure failure, {
    required void Function() onRetry,
    required void Function() onPermanent,
  }) => switch (failure) {
    SourceFailure(reason: SourceFailureReason.unavailable) ||
    SourceFailure(reason: SourceFailureReason.unknown) ||
    CoordinationTimeoutFailure() ||
    SnapshotExpiredFailure() => onRetry(),
    SnapshotNotInitializedFailure() ||
    WalletRegistrationMismatchFailure() ||
    WalletSourceStateMissingFailure() ||
    WalletSourceStateIncompatibleFailure() ||
    DeletedWalletFailure() ||
    SourceFailure(reason: SourceFailureReason.rejected) ||
    SourceObservationMismatchFailure() ||
    ExtractionFailure() ||
    DeletionFailure() ||
    InvalidPaginationFailure() => onPermanent(),
  };

  static void _classifyNotification(
    NotificationsFailure failure, {
    required void Function() onRetry,
    required void Function() onPermanent,
  }) => switch (failure) {
    UnknownNotificationDestinationFailure() ||
    InvalidNotificationPayloadFailure() => onPermanent(),
    NotificationsStorageFailure() ||
    NotificationsGatewayFailure() ||
    NotificationsClaimLostFailure() => onRetry(),
  };
}
