import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CreateSwapMasterKeyUsecase {
  final BoltzSwapRepository _mainnetRepository;
  final BoltzSwapRepository _testnetRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  CreateSwapMasterKeyUsecase({
    required BoltzSwapRepository mainnetRepository,
    required BoltzSwapRepository testnetRepository,
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
    required SeedRepository seedRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository,
       _walletRepository = walletRepository,
       _seedRepository = seedRepository;

  Future<void> execute() async {
    try {
      // Get the current active network from settings
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repository = isTestnet ? _testnetRepository : _mainnetRepository;

      // Check if SwapMasterKey already exists for the active network
      final exists = await repository.swapMasterKeyExists();
      if (exists) {
        return;
      }

      // Get default wallets for the active network
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: settings.environment,
      );

      if (defaultWallets.isEmpty) {
        log.info(
          'No default wallets found for active network, skipping SwapMasterKey creation',
        );
        return;
      }

      // Get the seed for the default wallet
      final defaultWallet = defaultWallets.first;
      final seed = await _seedRepository.get(defaultWallet.masterFingerprint);

      if (seed is! MnemonicSeed) {
        log.info(
          'Default seed is not a mnemonic seed, skipping SwapMasterKey creation',
        );
        return;
      }

      final mnemonic = seed.mnemonicWords.join(' ');

      // Create SwapMasterKey for the active network
      await repository.createSwapMasterKey(mnemonic: mnemonic);
    } catch (e) {
      log.severe('Error creating SwapMasterKey: $e');
      // Don't throw - this is a background operation that shouldn't block app startup
    }
  }
}
