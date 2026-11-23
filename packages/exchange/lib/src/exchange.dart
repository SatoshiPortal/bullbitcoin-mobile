import 'package:bbx_api/bbx_api.dart';
import 'package:primitives/primitives.dart';

import 'data/pending_orders.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';

/// Bull Bitcoin exchange capabilities.
final class Exchange {
  final Future<Result<bool, ExchangeFailure>> Function() _hasPendingOrders;

  const Exchange._(this._hasPendingOrders);

  /// Opens the capability without doing I/O. [readSession] must return an
  /// authoritative snapshot of the current session; its epoch must change when
  /// the environment or access changes, even if the same key is later reused.
  /// The credential is never published by an Exchange operation.
  static Exchange open({
    required Uri mainnetEndpoint,
    required Uri testnetEndpoint,
    required Future<
      Result<
        ({ExchangeEnvironment environment, int epoch, String? apiKey}),
        ExchangeFailure
      >
    >
    Function()
    readSession,
  }) {
    final inventory = PendingOrders(
      readSession: () async => (await readSession()).map(
        (session) => (
          endpoint: switch (session.environment) {
            ExchangeEnvironment.mainnet => mainnetEndpoint,
            ExchangeEnvironment.testnet => testnetEndpoint,
          },
          environment: session.environment,
          epoch: session.epoch,
          apiKey: session.apiKey,
        ),
      ),
      openClient: (endpoint, readKey) => Bbx.open(
        endpoint: endpoint.toString(),
        readActiveApiKey: readKey,
        timeouts: BbxTimeouts.standard,
      ),
    );
    return Exchange._(inventory.hasPendingOrders);
  }

  /// Returns false only after scanning a complete, stable session inventory.
  /// A signed-out account cannot establish absence.
  Future<Result<bool, ExchangeFailure>> hasPendingOrders() =>
      _hasPendingOrders();
}
