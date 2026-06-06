import 'package:bb_mobile/core/blockchain/data/repository/bitcoin_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:convert/convert.dart';

class BroadcastBitcoinTransactionUsecase {
  final BitcoinBlockchainRepository _bitcoinBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastBitcoinTransactionUsecase({
    required BitcoinBlockchainRepository bitcoinBlockchainRepository,
    required SettingsRepository settingsRepository,
  }) : _bitcoinBlockchain = bitcoinBlockchainRepository,
       _settingsRepository = settingsRepository;

  Future<String> execute(String transaction, {required bool isPsbt}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;

      if (isPsbt) {
        return await _bitcoinBlockchain.broadcastPsbt(
          transaction,
          isTestnet: isTestnet,
        );
      }
      return await _bitcoinBlockchain.broadcastTransaction(
        hex.decode(transaction),
        isTestnet: isTestnet,
      );
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}
