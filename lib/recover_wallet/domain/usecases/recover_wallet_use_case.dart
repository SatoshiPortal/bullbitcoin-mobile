import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/seed_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager.dart';

class RecoverWalletUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final SeedRepository _seedRepository;
  final WalletManager _walletManager;

  RecoverWalletUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required SeedRepository seedRepository,
    required WalletManager walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _seedRepository = seedRepository,
        _walletManager = walletManager;

  Future<Wallet> execute({
    required List<String> mnemonicWords,
    String? passphrase,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final environment = await _settingsRepository.getEnvironment();
    final bitcoinNetwork = environment == Environment.mainnet
        ? Network.bitcoinMainnet
        : Network.bitcoinTestnet;

    final mnemonicSeed = _mnemonicSeedFactory.fromWords(
      mnemonicWords,
      passphrase: passphrase,
    );

    // Store the seed
    await _seedRepository.storeSeed(mnemonicSeed);

    // Now that the seed is stored, create the wallet
    final wallet = _walletManager.createWallet(
      seed: mnemonicSeed,
      network: bitcoinNetwork,
      scriptType: scriptType,
      label: label,
    );

    return wallet;
  }
}
