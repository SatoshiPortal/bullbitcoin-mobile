import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:primitives/primitives.dart';
import 'domain/observation.dart';
import 'package:transaction_sync/transaction_sync.dart';

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

  /// The observed payments of one wallet, carrying no user-facing text.
  static Observation observation(WalletKey key, Iterable<String> txids) =>
      Observation(topicId(key), txids.map((txid) => eventId(key, txid)));

  static String _chain(Network network) => switch (network) {
    BitcoinNetwork() => 'bitcoin',
    LiquidNetwork() => 'liquid',
  };

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();
}
