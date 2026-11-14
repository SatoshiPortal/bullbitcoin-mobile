import 'dart:convert';

import 'package:background_tasks/background_tasks.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

/// The wallet's payments as notification events: what a visible sync saw is
/// recorded silently, what a background sync found is announced. Snapshot
/// readers never use this owner.
final class WalletPaymentObserver implements PaymentAnnouncementPort {
  final Future<NotificationsFacade> Function() _notifications;
  final bool Function() _isForeground;
  final ({String title, String body}) Function(int count) _copy;

  /// Records foreground sync completions; announces nothing.
  const WalletPaymentObserver.foreground(
    this._notifications, {
    required this._isForeground,
  }) : _copy = _noAnnouncement;

  /// Announces what background syncs found, with the localized [copy].
  const WalletPaymentObserver.background(
    this._notifications, {
    required this._copy,
  }) : _isForeground = _hidden;

  /// A sync completion of the foreground engine. Only a visible app records
  /// it: what the user could see is never announced later.
  Future<Result<void, TransactionSyncFailure>> recordCompletion(
    SyncCompletion completion,
  ) async {
    // Capture before ANY await, including opening the durable store.
    final visible = _isForeground();
    final incoming = completion.incomingTxids;
    if (!visible || incoming == null) return const Ok(null);
    final revision = completion.revision;
    if (revision == null) return const Err(TransactionSyncStorageFailure());
    try {
      final notifications = await _notifications();
      final recorded = await notifications.recordForeground(
        _observation(revision.key, incoming),
      );
      if (recorded is Err) {
        log.warning('Payment observation persistence failed');
        return const Err(TransactionSyncStorageFailure());
      }
      log.fine(
        'Payment observation recorded foreground=true incoming=${incoming.length} revision=${revision.revision}',
      );
      return const Ok(null);
    } on Exception {
      log.warning('Payment observation storage unavailable');
      return const Err(TransactionSyncStorageFailure());
    }
  }

  @override
  Future<Result<void, PaymentAnnouncementFailure>> record(
    BackgroundSyncOutcome outcome,
  ) async {
    final incoming = outcome.incomingTxids;
    if (incoming == null) return const Ok(null);
    try {
      final notifications = await _notifications();
      final recorded = await notifications.recordBackground(
        _observation(outcome.revision.key, incoming),
        (newEventIds) {
          final copy = _copy(newEventIds.length);
          return LocalNotification(
            // One aggregate per set of new payments.
            eventId: _hash((newEventIds.toList()..sort()).join('|')),
            title: copy.title,
            body: copy.body,
            createdAt: outcome.completedAt,
          );
        },
      );
      return switch (recorded) {
        Ok() => const Ok(null),
        Err() => const Err(PaymentAnnouncementUnavailableFailure()),
      };
    } on Exception {
      return const Err(PaymentAnnouncementUnavailableFailure());
    }
  }

  @override
  Future<Result<void, PaymentAnnouncementFailure>> deliverPending() async {
    try {
      final notifications = await _notifications();
      return switch (await notifications.deliverPending()) {
        Ok() => const Ok(null),
        Err(failure: NotificationsPermissionDeniedFailure()) => const Err(
          PaymentAnnouncementDeniedFailure(),
        ),
        Err() => const Err(PaymentAnnouncementUnavailableFailure()),
      };
    } on Exception {
      return const Err(PaymentAnnouncementUnavailableFailure());
    }
  }

  static bool _hidden() => false;

  static ({String title, String body}) _noAnnouncement(int count) =>
      throw StateError('The foreground observer announces nothing');
}

// The foreground and the background must agree on these identities, or a
// payment seen in the app would still be announced later.
const _identityPrefix = 'background-notifications-v1';

/// The observed payments of one wallet, carrying no user-facing text.
Observation _observation(WalletKey key, Iterable<String> txids) {
  final topic = _topic(key);
  return Observation(_hash(topic), txids.map((txid) => _hash('$topic|$txid')));
}

String _topic(WalletKey key) {
  final chain = switch (key.network) {
    BitcoinNetwork() => 'bitcoin',
    LiquidNetwork() => 'liquid',
  };
  return '$_identityPrefix|${key.id}|$chain|${key.network.env.name}';
}

String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
