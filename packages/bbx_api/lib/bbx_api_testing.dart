/// Test support for consumers of `package:bbx_api`.
///
/// [bbxForTesting] builds a real [Bbx] over caller-supplied HTTP
/// adapter, so a test asserts on the requests the production transports
/// actually send. Import this in `test/` only: it is not exported by
/// `package:bbx_api/bbx_api.dart`.
library;

import 'package:bbx_api/bbx_api.dart';
import 'package:bbx_api/src/bbx_transport.dart';
import 'package:bbx_api/src/orders/orders_wire.dart';
import 'package:bbx_api/src/recipients/recipients_wire.dart';
import 'package:bbx_api/src/users/users_wire.dart';
import 'package:dio/dio.dart' show HttpClientAdapter;
import 'package:primitives/primitives.dart';

/// A [Bbx] for the API at [endpoint] whose HTTP requests go to [adapter].
///
/// [readActiveApiKey] runs before every HTTP request, exactly as in [Bbx.open].
Bbx bbxForTesting({
  required String endpoint,
  required HttpClientAdapter adapter,
  required Future<Result<String?, BbxFailure>> Function() readActiveApiKey,
  BbxTimeouts timeouts = const BbxTimeouts(),
}) => Bbx.fromTransport(
  BbxTransport.testing(
    endpoint: endpoint,
    adapter: adapter,
    readActiveApiKey: readActiveApiKey,
    timeouts: timeouts,
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
