import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required SettingsRepository settingsRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository,
       _settingsRepository = settingsRepository;

  Future<String> execute(String psbt) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final txId = await _bitcoinBlockchain.broadcastPsbt(
        psbt,
        isTestnet: environment.isTestnet,
      );

      return txId;
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}

class BroadcastTransactionException implements Exception {
  final String message;

  BroadcastTransactionException(this.message);
}
