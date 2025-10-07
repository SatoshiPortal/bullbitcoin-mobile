import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:convert/convert.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;
  final ElectrumServerPort _electrumServerPort;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required SettingsRepository settingsRepository,
    required ElectrumServerPort electrumServerPort,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository,
       _settingsRepository = settingsRepository,
       _electrumServerPort = electrumServerPort;

  Future<String> execute(String transaction, {required bool isPsbt}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      final allElectrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: environment.isTestnet,
        isLiquid: false,
      );

      // If no Electrum servers are available, throw an error
      if (allElectrumServers.isEmpty) {
        throw BroadcastTransactionException(
          'No Electrum servers available for Bitcoin network.',
        );
      }

      // Filter out custom servers if they exist
      final customServers =
          allElectrumServers.where((server) => server.isCustom).toList();

      // Use custom servers only if available, otherwise use default servers
      final electrumServers =
          customServers.isNotEmpty ? customServers : allElectrumServers;

      String txid;
      if (isPsbt) {
        txid = await _bitcoinBlockchain.broadcastPsbt(
          transaction,
          electrumServers: electrumServers,
        );
      } else {
        txid = await _bitcoinBlockchain.broadcastTransaction(
          hex.decode(transaction),
          electrumServers: electrumServers,
        );
      }

      return txid;
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}
