import 'package:bb_mobile/core/blockchain/domain/repositories/liquid_blockchain_repository.dart';
import 'package:bb_mobile/core/errors/send_errors.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class BroadcastLiquidTransactionUsecase {
  final LiquidBlockchainRepository _liquidBlockchain;
  final SettingsRepository _settingsRepository;

  BroadcastLiquidTransactionUsecase({
    required LiquidBlockchainRepository liquidBlockchainRepository,
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository,
       _liquidBlockchain = liquidBlockchainRepository;

  Future<String> execute(String signedPset) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final txId = await _liquidBlockchain.broadcastTransaction(
        signedPset: signedPset,
        isTestnet: environment.isTestnet,
      );

      return txId;
    } catch (e) {
      throw BroadcastTransactionException(e.toString());
    }
  }
}
