import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;
  final SettingsRepository _settingsRepository;
  final ElectrumServerPort _electrumServerPort;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SettingsRepository settingsRepository,
    required ElectrumServerPort electrumServerPort,
  }) : _settingsRepository = settingsRepository,
       _liquidBlockchain = liquidBlockchainRepository,
       _electrumServerPort = electrumServerPort;

  Future<String> execute(String signedPset) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      final allElectrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: environment.isTestnet,
        isLiquid: true,
      );

      // If no Electrum servers are available, throw an error
      if (allElectrumServers.isEmpty) {
        throw BroadcastTransactionException(
          'No Electrum servers available for Liquid network.',
        );
      }

      // Filter out custom servers if they exist
      final customServers =
          allElectrumServers.where((server) => server.isCustom).toList();

      // Use custom servers only if available, otherwise use default servers
      final electrumServers =
          customServers.isNotEmpty ? customServers : allElectrumServers;

      final txId = await _liquidBlockchain.broadcastTransaction(
        signedPset: signedPset,
        electrumServers: electrumServers,
      );

      return txId;
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}
