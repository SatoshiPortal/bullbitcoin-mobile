import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_timeouts.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/commcenter/commcenter_api.dart';
import 'package:bbx_api/src/kyc/kyc_api.dart';
import 'package:bbx_api/src/order_triggers/order_triggers_api.dart';
import 'package:bbx_api/src/notifications/bbx_notification.dart';
import 'package:bbx_api/src/notifications/notification_socket.dart';
import 'package:bbx_api/src/orders/orders_api.dart';
import 'package:bbx_api/src/prices/prices_api.dart';
import 'package:bbx_api/src/recipients/recipients_api.dart';
import 'package:bbx_api/src/users/users_api.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The Bull Bitcoin exchange API at [open]'s endpoint.
///
/// Each operation returns [Result] of its own type and a [BbxFailure]. The
/// credential is read before every request through [open]'s
/// `readActiveApiKey`: `Ok(null)` is [BbxMissingCredentialFailure], `Err` is
/// [BbxCredentialUnavailableFailure], and neither sends a request. An [Error]
/// from that read propagates unchanged.
///
/// Owned values cross the API boundary; their wire JSON and parsers stay
/// internal. See [notifications], [CommcenterApi], [KycApi], [OrderTriggersApi],
/// [OrdersApi], [PricesApi], [RecipientsApi] and [UsersApi] for the supported
/// capabilities.
final class Bbx {
  final BbxTransport _transport;

  final BbxNotificationSocket notifications;

  late final CommcenterApi commcenter = CommcenterApi(_transport);
  late final KycApi kyc = KycApi(_transport);
  late final OrderTriggersApi orderTriggers = OrderTriggersApi(_transport);
  late final OrdersApi orders = OrdersApi(_transport);
  late final PricesApi prices = PricesApi(_transport);
  late final RecipientsApi recipients = RecipientsApi(_transport);
  late final UsersApi users = UsersApi(_transport);

  /// Wraps the transport and notification socket. Internal: callers use
  /// [Bbx.open] and tests use `package:bbx_api/bbx_api_testing.dart`.
  @internal
  Bbx.fromTransport(this._transport, {required this.notifications});

  /// The API at [endpoint], authenticated with the key [readActiveApiKey]
  /// returns for each request.
  ///
  /// [timeouts] bounds each request phase; the default waits with no timeout,
  /// and [BbxTimeouts.standard] applies the app's 30 seconds.
  static Bbx open({
    required String endpoint,
    required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
    BbxTimeouts timeouts = const BbxTimeouts(),
    BbxNotificationLog notificationLog = _ignoreNotificationLog,
  }) => Bbx.fromTransport(
    BbxTransport.open(
      endpoint: endpoint,
      readActiveApiKey: readActiveApiKey,
      timeouts: timeouts,
    ),
    notifications: openBbxNotificationSocket(
      baseUrl: endpoint,
      readApiKey: readActiveApiKey,
      log: notificationLog,
    ),
  );

  /// Whether the server answered HTTP 401 to a request this client sent with
  /// its key: the key is no longer valid. The owner of the session decides
  /// what to do with it; a request that was not sent never sets it.
  bool get sessionRejected => _transport.sessionRejected;

  /// Releases the HTTP transport and notification socket owned by this client.
  void dispose() {
    notifications.dispose();
    _transport.http.close(force: true);
  }
}

void _ignoreNotificationLog(
  BbxNotificationLogLevel level,
  String message, {
  Type? error,
}) {}
