import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class RecoverOrCreateWalletUsecase {
  final SettingsRepository _settingsRepository;
  final SeedRepository _seedRepository;
  final WalletRepository _walletRepository;

  RecoverOrCreateWalletUsecase({
    required SettingsRepository settingsRepository,
    required SeedRepository seedRepository,
    required WalletRepository walletRepository,
  }) : _settingsRepository = settingsRepository,
       _seedRepository = seedRepository,
       _walletRepository = walletRepository;

  Future<Wallet> execute({
    required List<String> mnemonicWords,
    String? passphrase,
    required ScriptType scriptType,
    String label = '',
    Network? network,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork =
          network ??
          (environment == Environment.mainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet);

      // Store the seed in the repository
      final mnemonicSeed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      // Now that the seed is stored, we can create the wallet
      final wallet = await _walletRepository.createWallet(
        seed: mnemonicSeed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
      );

      return wallet;
    } catch (e) {
      throw RecoverOrCreateWalletException('$e');
    }
  }
}

class RecoverOrCreateWalletException implements Exception {
  final String message;

  RecoverOrCreateWalletException(this.message);
}
