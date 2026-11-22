import 'package:bbx_api/src/bbx_failure.dart';
import 'package:bbx_api/src/bbx_timeouts.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/commcenter/commcenter_api.dart';
import 'package:bbx_api/src/kyc/kyc_api.dart';
import 'package:bbx_api/src/order_triggers/order_triggers_api.dart';
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
/// internal. See [CommcenterApi], [KycApi], [OrderTriggersApi],
/// [OrdersApi], [PricesApi], [RecipientsApi] and [UsersApi] for the supported
/// capabilities.
final class Bbx {
  final BbxTransport _transport;

  late final CommcenterApi commcenter = CommcenterApi(_transport);
  late final KycApi kyc = KycApi(_transport);
  late final OrderTriggersApi orderTriggers = OrderTriggersApi(_transport);
  late final OrdersApi orders = OrdersApi(_transport);
  late final PricesApi prices = PricesApi(_transport);
  late final RecipientsApi recipients = RecipientsApi(_transport);
  late final UsersApi users = UsersApi(_transport);

  /// Wraps the transport. Internal: callers use
  /// [Bbx.open] and tests use `package:bbx_api/bbx_api_testing.dart`.
  @internal
  Bbx.fromTransport(this._transport);

  /// The API at [endpoint], authenticated with the key [readActiveApiKey]
  /// returns for each request.
  ///
  /// [timeouts] bounds each request phase; the default waits with no timeout,
  /// and [BbxTimeouts.standard] applies the app's 30 seconds.
  static Bbx open({
    required String endpoint,
    required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
    BbxTimeouts timeouts = const BbxTimeouts(),
  }) => Bbx.fromTransport(
    BbxTransport.open(
      endpoint: endpoint,
      readActiveApiKey: readActiveApiKey,
      timeouts: timeouts,
    ),
  );
}
