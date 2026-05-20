import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/transactions/data/mappers/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/transactions/domain/ports/transaction_port.dart';

/// Adapter implementing [TransactionPort] for the Electrum module.
///
/// Iterates the configured Electrum servers in priority order, falling back
/// on failure, then maps the parsed [BitcoinTx] into a [Transaction] domain
/// entity and surfaces failures as [TransactionError] so the transactions
/// module never sees electrum's error types.
class ElectrumTransactionPortAdapter implements TransactionPort {
  final ElectrumServersPort _serversPort;
  final ElectrumTransactionRepository _repository;
  final EnvironmentPort _environmentPort;

  const ElectrumTransactionPortAdapter({
    required ElectrumServersPort serversPort,
    required ElectrumTransactionRepository repository,
    required EnvironmentPort environmentPort,
  }) : _serversPort = serversPort,
       _repository = repository,
       _environmentPort = environmentPort;

  @override
  Future<Transaction> fetch({required String txid}) async {
    final environment = await _environmentPort.getEnvironment();
    final network = ElectrumServerNetwork.fromEnvironment(
      isTestnet: environment.isTestnet,
      isLiquid: false,
    );

    final servers = await _serversPort.getServersToUse(network: network);
    if (servers.isEmpty) {
      throw TransactionError.noServersAvailable(network: network.toString());
    }

    Object? lastError;
    for (final server in servers) {
      try {
        final bitcoinTx = await _repository.fetch(
          serverUrl: server.url,
          txid: txid,
        );
        return TransactionMapper.fromBitcoinTx(
          bitcoinTx,
          isTestnet: environment.isTestnet,
        );
      } catch (e) {
        lastError = e;
        continue;
      }
    }

    throw TransactionError.fetchFailed(txid: txid, message: '$lastError');
  }
}
