import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/repositories/wallet_metadata_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/wallet_metadata_derivation_service.dart';
import 'package:bb_mobile/core/domain/services/wallet_repository_manager.dart';
import 'package:flutter/material.dart';

class CreateDefaultWalletsUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final SeedRepository _seedRepository;
  final WalletMetadataDerivationService _walletMetadataDerivationService;
  final WalletMetadataRepository _walletMetadataRepository;
  final WalletRepositoryManager _walletRepositoryManager;

  CreateDefaultWalletsUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required SeedRepository seedRepository,
    required WalletMetadataDerivationService walletMetadataDerivationService,
    required WalletMetadataRepository walletMetadataRepository,
    required WalletRepositoryManager walletRepositoryManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _seedRepository = seedRepository,
        _walletMetadataDerivationService = walletMetadataDerivationService,
        _walletMetadataRepository = walletMetadataRepository,
        _walletRepositoryManager = walletRepositoryManager;

  Future<void> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    final environment = await _settingsRepository.getEnvironment();

    // Generate a mnemonic seed if the user creates a new wallet
    //  or use the provided mnemonic words in case of recovery.
    final mnemonicSeed = mnemonicWords == null
        ? await _mnemonicSeedFactory.generate(passphrase: passphrase)
        : _mnemonicSeedFactory.fromWords(mnemonicWords, passphrase: passphrase);

    // Two default wallets are created for the user at onboarding,
    //  one bitcoin wallet and one liquid wallet.
    // The current default script type for the wallets is BIP84
    const scriptType = ScriptType.bip84;
    final defaultWalletsMetadata = await Future.wait([
      _walletMetadataDerivationService.fromSeed(
        seed: mnemonicSeed,
        network: environment == Environment.mainnet
            ? Network.bitcoinMainnet
            : Network.bitcoinTestnet,
        scriptType: scriptType,
        isDefault: true,
      ),
      _walletMetadataDerivationService.fromSeed(
        seed: mnemonicSeed,
        network: environment == Environment.mainnet
            ? Network.liquidMainnet
            : Network.liquidTestnet,
        scriptType: scriptType,
        isDefault: true,
      ),
    ]);

    // Store the seed, default wallets metadata and
    //  register them in the wallet repository manager so they can be used
    //  in the app.
    await Future.wait([
      _seedRepository.storeSeed(mnemonicSeed),
      _walletMetadataRepository.storeWalletMetadata(defaultWalletsMetadata[0]),
      _walletMetadataRepository.storeWalletMetadata(defaultWalletsMetadata[1]),
      _walletRepositoryManager.registerWallet(defaultWalletsMetadata[0]),
      _walletRepositoryManager.registerWallet(defaultWalletsMetadata[1]),
    ]);
    debugPrint('Default wallets created');
  }
}
