/// Test support for consumers of `package:bbx_api`.
///
/// [bbxForTesting] builds a real [Bbx] over caller-supplied HTTP and socket
/// adapters, so a test asserts on the requests the production transports
/// actually send. Import this in `test/` only: it is not exported by
/// `package:bbx_api/bbx_api.dart`.
library;

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/notifications/notification_socket.dart';
import 'package:bbx_api/src/orders/orders_wire.dart';
import 'package:bbx_api/src/recipients/recipients_wire.dart';
import 'package:bbx_api/src/users/users_wire.dart';
import 'package:dio/dio.dart' show HttpClientAdapter;
import 'package:primitives/primitives.dart';

export 'package:bbx_api/src/notifications/notification_socket.dart'
    show BbxWebSocketConnector, bbxNotificationSocketForTesting;

/// A [Bbx] for the API at [endpoint] whose HTTP requests go to [adapter].
///
/// [readActiveApiKey] runs before every HTTP request and socket handshake,
/// exactly as in [Bbx.open]. Socket connections use [connector] when given.
Bbx bbxForTesting({
  required String endpoint,
  required HttpClientAdapter adapter,
  required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
  BbxTimeouts timeouts = const BbxTimeouts(),
  BbxWebSocketConnector? connector,
  BbxNotificationLog notificationLog = _ignoreNotificationLog,
}) => Bbx.fromTransport(
  BbxTransport.testing(
    endpoint: endpoint,
    adapter: adapter,
    readActiveApiKey: readActiveApiKey,
    timeouts: timeouts,
  ),
  notifications: bbxNotificationSocketForTesting(
    baseUrl: endpoint,
    readApiKey: readActiveApiKey,
    connector: connector,
    log: notificationLog,
  ),
);

/// Decodes an order fixture through the same internal codec as the endpoint.
OrderSummary orderSummaryForTesting(Map<String, dynamic> json) =>
    parseOrderSummary(json);

/// Decodes a user-summary fixture through the same codec as the endpoint.
UserSummary userSummaryForTesting(Map<String, dynamic> json) =>
    parseUserSummary(json);

/// Encodes a recipient fixture through the same codec as the endpoint.
Map<String, Object?> newFiatRecipientJsonForTesting(
  NewFiatRecipient recipient,
) => newFiatRecipientToJson(recipient);

/// Encodes a preferences fixture through the same codec as the endpoint.
Map<String, String> userPreferencesJsonForTesting(
  UserPreferences preferences,
) => userPreferencesToJson(preferences);

void _ignoreNotificationLog(
  BbxNotificationLogLevel level,
  String message, {
  Type? error,
}) {}
