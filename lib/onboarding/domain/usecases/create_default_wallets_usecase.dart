import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';
import 'package:flutter/material.dart';

class CreateDefaultWalletsUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final SeedRepository _seedRepository;
  final WalletManager _walletManager;

  CreateDefaultWalletsUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required SeedRepository seedRepository,
    required WalletManager walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _seedRepository = seedRepository,
        _walletManager = walletManager;

  Future<void> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    // Generate a mnemonic seed if the user creates a new wallet
    //  or use the provided mnemonic words in case of recovery.
    final mnemonicSeed = mnemonicWords == null
        ? await _mnemonicSeedFactory.generate(passphrase: passphrase)
        : _mnemonicSeedFactory.fromWords(mnemonicWords, passphrase: passphrase);

    // The current default script type for the wallets is BIP84
    const scriptType = ScriptType.bip84;

    // Get the current environment to determine the network
    final environment = await _settingsRepository.getEnvironment();
    final bitcoinNetwork = environment == Environment.mainnet
        ? Network.bitcoinMainnet
        : Network.bitcoinTestnet;
    final liquidNetwork = environment == Environment.mainnet
        ? Network.liquidMainnet
        : Network.liquidTestnet;

    // Store the seed and create the default wallets, 1 bitcoin and 1 liquid wallet.
    await Future.wait([
      _seedRepository.storeSeed(mnemonicSeed),
      _walletManager.createWallet(
        seed: mnemonicSeed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: true,
      ),
      _walletManager.createWallet(
        seed: mnemonicSeed,
        network: liquidNetwork,
        scriptType: scriptType,
        isDefault: true,
      ),
    ]);

    debugPrint('Default wallets created');
  }
}
