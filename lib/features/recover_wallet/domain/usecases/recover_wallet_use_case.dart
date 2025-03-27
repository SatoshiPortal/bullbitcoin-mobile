import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager_service.dart';

class RecoverOrCreateWalletUsecase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final WalletManagerService _walletManager;

  RecoverOrCreateWalletUsecase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required WalletManagerService walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
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

    final wallet = _walletManager.createWallet(
      seed: mnemonicSeed,
      network: bitcoinNetwork,
      scriptType: scriptType,
      label: label,
    );

    return wallet;
  }
}
