import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';

/// Fetches a Bitcoin transaction by txid via Electrum RPC.
///
/// Resolves the correct network dynamically via [EnvironmentPort],
/// selects servers in priority order via [GetElectrumServersToUseUsecase],
/// and falls back to the next server on failure.
class FetchElectrumTransactionUsecase {
  final ElectrumTransactionRepository _repository;
  final GetElectrumServersToUseUsecase _getServersUsecase;
  final EnvironmentPort _environmentPort;

  const FetchElectrumTransactionUsecase({
    required ElectrumTransactionRepository repository,
    required GetElectrumServersToUseUsecase getServersUsecase,
    required EnvironmentPort environmentPort,
  }) : _repository = repository,
       _getServersUsecase = getServersUsecase,
       _environmentPort = environmentPort;

  /// Fetch a Bitcoin transaction by txid as a [Transaction] domain entity.
  ///
  /// Tries servers in priority order. If one fails, falls back to the next.
  Future<Transaction> execute({required String txid}) async {
    final environment = await _environmentPort.getEnvironment();
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: environment.isTestnet,
      isLiquid: false,
    );

    final response = await _getServersUsecase.execute(
      GetElectrumServersToUseRequest(network: network),
    );

    if (response.servers.isEmpty) {
      throw TransactionError.noServersAvailable(network: network.toString());
    }

    Object? lastError;
    for (final server in response.servers) {
      try {
        return await _repository.fetch(
          serverUrl: server.url,
          txid: txid,
          isTestnet: environment.isTestnet,
        );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw TransactionError.fetchFailed(
      txid: txid,
      message: lastError.toString(),
    );
  }
}
