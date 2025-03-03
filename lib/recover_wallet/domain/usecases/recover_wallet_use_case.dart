import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';

class RecoverWalletUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final WalletManagerRepository _walletManager;

  RecoverWalletUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required WalletManagerRepository walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
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

    final wallet = _walletManager.createWallet(
      seed: mnemonicSeed,
      network: bitcoinNetwork,
      scriptType: scriptType,
      label: label,
    );

    return wallet;
  }
}
