import 'package:bb_mobile/core/bitcoin/domain/repositories/bitcoin_blockchain_repository.dart';

import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

class BroadcastBitcoinTransactionUsecase {
  final SettingsRepository _settings;
  final ElectrumServerRepository _electrumServer;
  final BitcoinBlockchainRepository _bitcoinBlockchain;

  BroadcastBitcoinTransactionUsecase({
    required SettingsRepository settings,
    required ElectrumServerRepository electrumServer,
    required BitcoinBlockchainRepository bitcoinBlockchain,
  })  : _settings = settings,
        _electrumServer = electrumServer,
        _bitcoinBlockchain = bitcoinBlockchain;

  Future<String> execute(String psbt) async {
    try {
      final environment = await _settings.getEnvironment();
      final electrumServer = await _electrumServer.getElectrumServer(
        network: Network.fromEnvironment(
          isTestnet: environment.isTestnet,
          isLiquid: false,
        ),
      );
      final txId = await _bitcoinBlockchain.broadcastPsbt(
        psbt,
        electrumServer: electrumServer,
      );

      return txId;
    } catch (e) {
      throw FailedToBroadcastTransactionException(e.toString());
    }
  }
}

class FailedToBroadcastTransactionException implements Exception {
  final String message;

  FailedToBroadcastTransactionException(this.message);
}
