import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:primitives/primitives.dart';

import '../domain/ports/background_wallet_sync_port.dart';
import '../domain/ports/payment_announcement_port.dart';
import '../domain/wallet_sync_chain.dart';

typedef NotificationCopy = ({String title, String body});
typedef NotificationCopyBuilder =
    NotificationCopy Function(int count, WalletSyncChain chain);

/// Phase A: announces through the notifications package from here, so this
/// package still depends on it. Phase B moves this mapping to the wallet
/// feature, next to the localized copy, and removes the dependency.
final class NotificationsPaymentAnnouncement
    implements PaymentAnnouncementPort {
  final NotificationsFacade _notifications;
  final NotificationCopyBuilder _copy;

  const NotificationsPaymentAnnouncement(this._notifications, this._copy);

  @override
  Future<Result<void, PaymentAnnouncementFailure>> record(
    BackgroundSyncOutcome outcome,
  ) async {
    final incoming = outcome.incomingTxids;
    if (incoming == null) return const Ok(null);
    final key = outcome.revision.key;
    final recorded = await _notifications.recordBackground(
      WalletPaymentNotificationIdentity.observation(key, incoming),
      (ids) {
        final text = _copy(ids.length, walletSyncChain(key));
        return LocalNotification(
          // One aggregate per set of new payments.
          eventId: sha256
              .convert(utf8.encode((ids.toList()..sort()).join('|')))
              .toString(),
          title: text.title,
          body: text.body,
          createdAt: outcome.completedAt,
        );
      },
    );
    return switch (recorded) {
      Ok() => const Ok(null),
      Err() => const Err(PaymentAnnouncementUnavailableFailure()),
    };
  }

  @override
  Future<Result<void, PaymentAnnouncementFailure>> deliverPending() async =>
      switch (await _notifications.deliverPending()) {
        Ok() => const Ok(null),
        Err(failure: NotificationsPermissionDeniedFailure()) => const Err(
          PaymentAnnouncementDeniedFailure(),
        ),
        Err() => const Err(PaymentAnnouncementUnavailableFailure()),
      };
}
