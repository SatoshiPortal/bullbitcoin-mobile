import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';
import 'package:flutter/material.dart';

class CreateDefaultWalletsUsecase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final WalletManagerService _walletManager;

  CreateDefaultWalletsUsecase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required WalletManagerService walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _walletManager = walletManager;

  Future<void> execute({
    List<String>? mnemonicWords,
    String? passphrase,
  }) async {
    try {
      // Generate a mnemonic seed if the user creates a new wallet
      //  or use the provided mnemonic words in case of recovery.
      final mnemonicSeed = mnemonicWords == null
          ? await _mnemonicSeedFactory.generate(passphrase: passphrase)
          : _mnemonicSeedFactory.fromWords(
              mnemonicWords,
              passphrase: passphrase,
            );

      // The current default script type for the wallets is BIP84
      const scriptType = ScriptType.bip84;

      // Get the current environment to determine the network
      final environment = await _settingsRepository.getEnvironment();
      final bitcoinNetwork = environment.isMainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;
      final liquidNetwork =
          environment.isMainnet ? Network.liquidMainnet : Network.liquidTestnet;

      // The default wallets should be 1 Bitcoin and 1 Liquid wallet.
      await Future.wait([
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
    } catch (e) {
      //TODO: Handle error - delete all wallets
      rethrow;
    }
  }
}
