import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/boltz_network.dart';

class GetSwapMnemonicUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetSwapMnemonicUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<String> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final network = isTestnet ? BoltzNetwork.testnet : BoltzNetwork.mainnet;
      final repository = isTestnet ? _testnetRepository : _mainnetRepository;

      final swapMasterKey = await repository.getSwapMasterKey(network: network);
      return swapMasterKey.mnemonic;
    } catch (e) {
      throw GetSwapMnemonicException('$e');
    }
  }
}

class GetSwapMnemonicException extends BullException {
  GetSwapMnemonicException(super.message);
}
