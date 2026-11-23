import 'package:bbx_api/bbx_api.dart';
import 'package:primitives/primitives.dart';

import 'data/bbx_api_kyc_repository.dart';
import 'data/bbx_api_order_stats_repository.dart';
import 'data/pending_orders.dart';
import 'domain/entities/order_stats.dart';
import 'domain/exchange_environment.dart';
import 'domain/exchange_failure.dart';

/// Bull Bitcoin exchange capabilities.
final class Exchange {
  final Future<Result<bool, ExchangeFailure>> Function() _hasPendingOrders;
  final Future<Result<OrderStatsResponse, ExchangeFailure>> Function()
  _getOrderStats;
  final Future<Result<void, ExchangeFailure>> Function({
    required List<int> fileBytes,
    required String fileName,
  })
  _uploadKycDocument;

  const Exchange._(
    this._hasPendingOrders,
    this._getOrderStats,
    this._uploadKycDocument,
  );

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
    Future<Result<InventorySession, ExchangeFailure>> sessionSnapshot() async =>
        (await readSession()).map(
          (session) => (
            endpoint: switch (session.environment) {
              ExchangeEnvironment.mainnet => mainnetEndpoint,
              ExchangeEnvironment.testnet => testnetEndpoint,
            },
            environment: session.environment,
            epoch: session.epoch,
            apiKey: session.apiKey,
          ),
        );

    Bbx openClient(
      Uri endpoint,
      Future<Result<String?, BbxFailure>> Function() readKey,
    ) => Bbx.open(
      endpoint: endpoint.toString(),
      readActiveApiKey: readKey,
      timeouts: BbxTimeouts.standard,
    );

    Future<Result<T, ExchangeFailure>> withClient<T>(
      Future<Result<T, ExchangeFailure>> Function(Bbx) operation,
    ) async {
      switch (await sessionSnapshot()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          var stale = false;
          final client = openClient(value.endpoint, () async {
            if (await sessionSnapshot() case Ok(value: final current)
                when current == value) {
              return Ok(value.apiKey);
            }
            stale = true;
            return const Err(BbxCredentialUnavailableFailure());
          });
          try {
            final result = await operation(client);
            return stale ? const Err(ExchangeOperationStaleFailure()) : result;
          } finally {
            client.dispose();
          }
      }
    }

    final inventory = PendingOrders(
      readSession: sessionSnapshot,
      openClient: openClient,
    );
    return Exchange._(
      inventory.hasPendingOrders,
      () => withClient(
        (client) => BbxApiOrderStatsRepository(api: client).getOrderStats(),
      ),
      ({required fileBytes, required fileName}) => withClient(
        (client) => BbxApiKycRepository(api: client).uploadDocument(
          fileBytes: fileBytes,
          fileName: fileName,
          docType: 'ID',
          sourceDetail: 'SECURE_UPLOAD',
        ),
      ),
    );
  }

  /// Returns false only after scanning a complete, stable session inventory.
  /// A signed-out account cannot establish absence.
  Future<Result<bool, ExchangeFailure>> hasPendingOrders() =>
      _hasPendingOrders();

  Future<Result<OrderStatsResponse, ExchangeFailure>> getOrderStats() =>
      _getOrderStats();

  Future<Result<void, ExchangeFailure>> uploadKycDocument({
    required List<int> fileBytes,
    required String fileName,
  }) => _uploadKycDocument(fileBytes: fileBytes, fileName: fileName);
}

/// Builds the public capability with scenario-controlled results.
Exchange exchangeForTesting({
  Future<Result<bool, ExchangeFailure>> Function()? hasPendingOrders,
  Future<Result<OrderStatsResponse, ExchangeFailure>> Function()? getOrderStats,
  Future<Result<void, ExchangeFailure>> Function({
    required List<int> fileBytes,
    required String fileName,
  })?
  uploadKycDocument,
}) => Exchange._(
  hasPendingOrders ?? () => throw StateError('Unexpected inventory request'),
  getOrderStats ?? () => throw StateError('Unexpected statistics request'),
  uploadKycDocument ??
      ({required fileBytes, required fileName}) =>
          throw StateError('Unexpected document upload'),
);
