import 'package:bb_mobile/core/electrum/domain/errors/electrum_fetch_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

/// Fetches a Bitcoin transaction by txid via Electrum RPC.
///
/// Selects servers in priority order via [ElectrumServersPort] and falls
/// back to the next server on failure. Returns the parsed [BitcoinTx];
/// callers handle mapping into their own domain types.
class FetchElectrumTransactionUsecase {
  final ElectrumTransactionRepository _repository;
  final ElectrumServersPort _serversPort;

  const FetchElectrumTransactionUsecase({
    required ElectrumTransactionRepository repository,
    required ElectrumServersPort serversPort,
  }) : _repository = repository,
       _serversPort = serversPort;

  /// Fetch a Bitcoin transaction by txid.
  ///
  /// Tries servers in priority order. If one fails, falls back to the next.
  /// Throws [ElectrumNoServersException] when no servers are configured for
  /// the network and [ElectrumFetchFailedException] when all servers fail.
  Future<BitcoinTx> execute({
    required String txid,
    required bool isTestnet,
  }) async {
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: isTestnet,
      isLiquid: false,
    );

    final servers = await _serversPort.getServersToUse(network: network);

    if (servers.isEmpty) {
      throw ElectrumNoServersException(network.toString());
    }

    Object? lastError;
    for (final server in servers) {
      try {
        return await _repository.fetch(serverUrl: server.url, txid: txid);
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw ElectrumFetchFailedException(txid: txid, cause: lastError);
  }
}
