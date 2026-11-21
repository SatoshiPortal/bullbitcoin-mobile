import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart' show BitcoinTx;

import 'domain/electrum_failure.dart';
import 'domain/electrum_server_network.dart';
import 'domain/errors/electrum_fallback_exception.dart';
import 'domain/ports/electrum_servers_port.dart';
import 'domain/ports/environment_port.dart';
import 'domain/repositories/electrum_transaction_repository.dart';

/// Reads parsed Bitcoin transactions through the active server policy.
class Electrum {
  final ElectrumServersPort _serversPort;
  final ElectrumTransactionRepository _repository;
  final EnvironmentPort _environmentPort;

  const Electrum({
    required this._serversPort,
    required this._repository,
    required this._environmentPort,
  });

  @useResult
  Future<Result<BitcoinTx, ElectrumFailure>> fetchBitcoinTransaction({
    required String txid,
  }) async {
    try {
      final environment = await _environmentPort.getEnvironment();
      final network = ElectrumServerNetwork.fromEnvironment(
        environment: environment,
        isLiquid: false,
      );
      return Ok(
        await _serversPort.runWithFallback(
          network: network,
          operation: (connection) =>
              _repository.fetch(connection: connection, txid: txid),
        ),
      );
    } on NoElectrumServersConfiguredException catch (failure) {
      return Err(ElectrumNoTransactionServersFailure(failure.network));
    } on AllElectrumServersFailedException {
      return Err(ElectrumTransactionFetchFailure(txid));
    } on Exception catch (failure) {
      return Err(ElectrumUnexpectedFailure(failure.runtimeType.toString()));
    }
  }
}
