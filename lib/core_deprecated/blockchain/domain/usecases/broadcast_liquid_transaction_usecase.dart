import 'package:bb_mobile/core_deprecated/blockchain/domain/ports/electrum_server_port.dart';
import 'package:bb_mobile/core_deprecated/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core_deprecated/errors/send_errors.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

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

  Future<String> execute(String signedPset, {bool? isTestnet}) async {
    try {
      isTestnet ??= (await _settingsRepository.fetch()).environment.isTestnet;

      final electrumServers = await _electrumServerPort.getElectrumServers(
        isTestnet: isTestnet,
        isLiquid: true,
      );

      // If no Electrum servers are available, throw an error
      if (electrumServers.isEmpty) {
        throw BroadcastTransactionException(
          'No Electrum servers available for Liquid network.',
        );
      }

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
