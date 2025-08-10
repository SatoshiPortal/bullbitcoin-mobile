import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CreatePreviewWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;

  final WalletRepository _wallet;

  CreatePreviewWalletsUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,
       _wallet = walletRepository;

  Future<List<Wallet>> execute({required List<String> mnemonicWords}) async {
    try {
      // Create and store the seed
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
      );

      // The current default script type for the wallets is BIP84
      const scriptType = ScriptType.bip84;

      // Get the current environment to determine the network
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork =
          environment.isMainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;
      final liquidNetwork =
          environment.isMainnet ? Network.liquidMainnet : Network.liquidTestnet;

      final previewWallets = await Future.wait([
        _wallet.createWallet(
          seed: seed,
          network: bitcoinNetwork,
          scriptType: scriptType,
          isDefault: true,
          persist: false,
          sync: true,
        ),
        _wallet.createWallet(
          seed: seed,
          network: liquidNetwork,
          scriptType: scriptType,
          isDefault: true,
          persist: false,
          sync: true,
        ),
      ]);

      return previewWallets;
    } catch (e) {
      log.severe('Failed to create default wallets: $e');
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException implements Exception {
  final String message;

  CreateDefaultWalletsException(this.message);
}
