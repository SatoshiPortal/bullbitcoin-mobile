import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:notifications/notifications.dart';
import 'package:transaction_sync/transaction_sync.dart';

/// Names a wallet's payment topic and its events. The background task and
/// the foreground observation must agree on these, or a payment seen in the
/// app would still be announced later.
final class WalletPaymentNotificationIdentity {
  static const _prefix = 'background-notifications-v1';

  static String topicId(WalletNetworkKey key) =>
      _hash('$_prefix|${key.walletId}|${key.chain}|${key.network}');

  static String eventId(WalletNetworkKey key, String txid) =>
      _hash('$_prefix|${key.walletId}|${key.chain}|${key.network}|$txid');

  /// An observed payment, carrying no user-facing text: only the aggregate
  /// built at reconciliation is ever shown.
  static LocalNotification event(
    WalletNetworkKey key,
    String txid, {
    required DateTime observedAt,
  }) => LocalNotification(
    eventId: eventId(key, txid),
    title: '',
    body: '',
    destination: NotificationDestination.walletHome,
    createdAt: observedAt,
  );

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
