import 'package:bb_mobile/core/blockchain/domain/repositories/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required SettingsRepository settingsRepository,
  })  : _bitcoinBlockchain = bitcoinBlockchainRepository,
        _settingsRepository = settingsRepository;

  Future<String> execute(String psbt) async {
    try {
      final environment = await _settingsRepository.getEnvironment();
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
