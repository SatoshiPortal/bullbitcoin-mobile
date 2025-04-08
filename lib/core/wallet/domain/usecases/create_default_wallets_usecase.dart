import 'package:bb_mobile/core/seed/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/core/seed/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:flutter/material.dart';

class CreateDefaultWalletsUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final WalletRepository _wallet;

  CreateDefaultWalletsUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required WalletRepository walletRepository,
  })  : _seedRepository = seedRepository,
        _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _wallet = walletRepository;

  Future<List<Wallet>> execute({
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
      // Store the seed in the repository
      await _seedRepository.store(
        fingerprint: mnemonicSeed.masterFingerprint,
        seed: mnemonicSeed,
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
      final defaultWallets = await Future.wait([
        _wallet.createWallet(
          seed: mnemonicSeed,
          network: bitcoinNetwork,
          scriptType: scriptType,
          isDefault: true,
        ),
        _wallet.createWallet(
          seed: mnemonicSeed,
          network: liquidNetwork,
          scriptType: scriptType,
          isDefault: true,
        ),
      ]);

      debugPrint('Default wallets created');

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
