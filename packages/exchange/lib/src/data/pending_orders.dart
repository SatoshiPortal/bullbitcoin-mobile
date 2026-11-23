import 'package:bbx_api/bbx_api.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/order.dart' show OrderStatus;
import '../domain/exchange_environment.dart';
import '../domain/exchange_failure.dart';

typedef InventorySession = ({
  Uri endpoint,
  ExchangeEnvironment environment,
  int epoch,
  String? apiKey,
});
typedef OpenInventoryClient = Bbx Function(
  Uri endpoint,
  Future<Result<String?, BbxFailure>> Function() readKey,
);

final class PendingOrders {
  static const _maximumPages = 1000;

  final Future<Result<InventorySession, ExchangeFailure>> Function()
  _readSession;
  final OpenInventoryClient _openClient;

  const PendingOrders({required this._readSession, required this._openClient});

  Future<Result<bool, ExchangeFailure>> hasPendingOrders() async {
    final initial = await _readSession();
    if (initial case Err(:final failure)) return Err(failure);
    final session = (initial as Ok<InventorySession, ExchangeFailure>).value;
    final key = session.apiKey;
    if (key == null || key.isEmpty) {
      return const Err(ExchangeNotAuthenticatedFailure());
    }

    Future<Result<String?, BbxFailure>> readMatchingKey() async =>
        switch (await _readSession()) {
          Ok(value: final current) when current == session => Ok(key),
          _ => const Err(BbxCredentialUnavailableFailure()),
        };

    final client = _openClient(session.endpoint, readMatchingKey);
    try {
      final seen = <String>{};
      for (var page = 1; page <= _maximumPages; page++) {
        final result = await client.orders.listOrderSummaries(
          page: page,
          requireCompletePage: true,
        );
        if (await readMatchingKey() case Err()) {
          return const Err(ExchangeOperationStaleFailure());
        }
        if (result case Err(:final failure)) {
          return Err(switch (failure) {
            BbxHttpFailure(status: 401) =>
              const ExchangeSessionRejectedFailure(),
            BbxCredentialUnavailableFailure() ||
            BbxMissingCredentialFailure() =>
              const ExchangeOperationStaleFailure(),
            BbxConnectionFailure() ||
            BbxTimeoutFailure() => const ExchangeNetworkFailure(),
            _ => const ExchangeOrderInventoryUnavailableFailure(),
          });
        }

        final orders =
            (result as Ok<OrderSummaryList, BbxFailure>).value.orders;
        if (orders.isEmpty) return const Ok(false);
        var hasPending = false;
        for (final order in orders) {
          final id = order.orderId.trim();
          final status = OrderStatus.fromValue(order.orderStatus ?? '');
          if (id.isEmpty || !seen.add(id) || status == OrderStatus.unknown) {
            return const Err(ExchangeOrderInventoryUnavailableFailure());
          }
          if (status == OrderStatus.inProgress ||
              status == OrderStatus.awaitingConfirmation) {
            hasPending = true;
          }
        }
        if (hasPending) return const Ok(true);
      }
      return const Err(ExchangeOrderInventoryUnavailableFailure());
    } finally {
      client.dispose();
    }
  }
}
