import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_manager_service.dart';

class RecoverOrCreateWalletUsecase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final SeedRepository _seedRepository;
  final WalletManagerService _walletManager;

  RecoverOrCreateWalletUsecase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required SeedRepository seedRepository,
    required WalletManagerService walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _seedRepository = seedRepository,
        _walletManager = walletManager;

  Future<Wallet> execute({
    required List<String> mnemonicWords,
    String? passphrase,
    required ScriptType scriptType,
    String label = '',
    Network? network,
  }) async {
    final environment = await _settingsRepository.getEnvironment();
    final bitcoinNetwork = network ??
        (environment == Environment.mainnet
            ? Network.bitcoinMainnet
            : Network.bitcoinTestnet);

    final mnemonicSeed = _mnemonicSeedFactory.fromWords(
      mnemonicWords,
      passphrase: passphrase,
    );

    // Store the seed in the repository
    await _seedRepository.store(
      fingerprint: mnemonicSeed.masterFingerprint,
      seed: mnemonicSeed,
    );

    // Now that the seed is stored, we can create the wallet
    final wallet = await _walletManager.createWallet(
      seed: mnemonicSeed,
      network: bitcoinNetwork,
      scriptType: scriptType,
      label: label,
    );

    return wallet;
  }
}
