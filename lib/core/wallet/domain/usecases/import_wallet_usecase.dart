import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ImportWalletUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;

  final WalletRepository _wallet;

  ImportWalletUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  }) : _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,

       _wallet = walletRepository;

  Future<List<Wallet>> execute({
    required List<String> mnemonicWords,
    String? passphrase,
  }) async {
    try {
      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
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
          label: seed.masterFingerprint,
          isDefault: false,
        ),
        _wallet.createWallet(
          seed: seed,
          network: liquidNetwork,
          label: seed.masterFingerprint,
          scriptType: scriptType,
          isDefault: false,
        ),
      ]);

      log.fine('Non default wallets created');

      return defaultWallets;
    } catch (e) {
      throw CreateDefaultWalletsException(e.toString());
    }
  }
}

class CreateDefaultWalletsException implements Exception {
  final String message;

  CreateDefaultWalletsException(this.message);
}
