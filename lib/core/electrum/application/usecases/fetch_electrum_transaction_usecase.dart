import 'package:bb_mobile/core/electrum/application/dtos/requests/get_electrum_servers_to_use_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/get_electrum_servers_to_use_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

/// Fetches a Bitcoin transaction by txid via Electrum RPC.
///
/// Resolves the correct network dynamically via [EnvironmentPort],
/// selects servers in priority order via [GetElectrumServersToUseUsecase],
/// and falls back to the next server on failure.
class FetchElectrumTransactionUsecase {
  final GetElectrumServersToUseUsecase _getServersUsecase;
  final EnvironmentPort _environmentPort;
  final SqliteDatabase _sqlite;

  const FetchElectrumTransactionUsecase({
    required GetElectrumServersToUseUsecase getServersUsecase,
    required EnvironmentPort environmentPort,
    required SqliteDatabase sqlite,
  }) : _getServersUsecase = getServersUsecase,
       _environmentPort = environmentPort,
       _sqlite = sqlite;

  /// Fetch a Bitcoin transaction by txid.
  ///
  /// Tries servers in priority order. If one fails, falls back to the next.
  Future<BitcoinTx> execute({required String txid}) async {
    final environment = await _environmentPort.getEnvironment();
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: environment.isTestnet,
      isLiquid: false,
    );

    final response = await _getServersUsecase.execute(
      GetElectrumServersToUseRequest(network: network),
    );

    if (response.servers.isEmpty) {
      throw Exception('No Electrum servers available for $network');
    }

    // Try servers in priority order — fallback on failure
    Object? lastError;
    for (final serverDto in response.servers) {
      try {
        final datasource = ElectrumRemoteDatasource(
          server: ElectrumServerModel(
            url: serverDto.url,
            network: serverDto.network,
          ),
          sqlite: _sqlite,
        );
        final model = await datasource.fetch(txid: txid);
        return TransactionModelExtension.toEntity(model);
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw Exception('All Electrum servers failed for txid $txid: $lastError');
  }
}
