import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'domain/local_notification.dart';
import 'domain/notification_destination.dart';
import 'package:sync/sync.dart';

/// Names a wallet's payment topic and its events. The background task and
/// the foreground observation must agree on these, or a payment seen in the
/// app would still be announced later.
final class WalletPaymentNotificationIdentity {
  static const _prefix = 'background-notifications-v1';

  static String topicId(WalletKey key) => _hash(
    '$_prefix|${key.id}|${_chain(key.network)}|${key.network.env.name}',
  );

  static String eventId(WalletKey key, String txid) => _hash(
    '$_prefix|${key.id}|${_chain(key.network)}|${key.network.env.name}|$txid',
  );

  /// An observed payment, carrying no user-facing text: only the aggregate
  /// built at reconciliation is ever shown.
  static LocalNotification event(
    WalletKey key,
    String txid, {
    required DateTime observedAt,
  }) => LocalNotification(
    eventId: eventId(key, txid),
    title: '',
    body: '',
    destination: NotificationDestination.walletHome,
    createdAt: observedAt,
  );

  static String _chain(Network network) => switch (network) {
    BitcoinNetwork() => 'bitcoin',
    LiquidNetwork() => 'liquid',
  };

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
