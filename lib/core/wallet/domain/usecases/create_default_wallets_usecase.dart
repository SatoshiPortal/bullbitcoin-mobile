import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicGenerator _mnemonicGenerator;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required MnemonicGenerator mnemonicGenerator,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,
       _mnemonicGenerator = mnemonicGenerator,
       _wallet = walletRepository;

  Future<List<Wallet>> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    try {
      // Generate a mnemonic seed if the user creates a new wallet
      //  or use the provided mnemonic words in case of recovery.
      final mnemonic = mnemonicWords ?? await _mnemonicGenerator.generate();
      // Create and store the seed
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonic,
        passphrase: passphrase,
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

      // The default wallets should be 1 Bitcoin and 1 Liquid wallet.
      final defaultWallets = await Future.wait([
        _wallet.createWallet(
          seed: seed,
          network: bitcoinNetwork,
          scriptType: scriptType,
          isDefault: true,
        ),
        _wallet.createWallet(
          seed: seed,
          network: liquidNetwork,
          scriptType: scriptType,
          isDefault: true,
        ),
      ]);

      log.fine('Default wallets created');

      return defaultWallets;
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
