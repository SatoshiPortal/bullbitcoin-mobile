import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/mnemonic_seed_factory.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class RecoverWalletUseCase {
  final SettingsRepository _settingsRepository;
  final MnemonicSeedFactory _mnemonicSeedFactory;
  final WalletManagerService _walletManager;

  RecoverWalletUseCase({
    required SettingsRepository settingsRepository,
    required MnemonicSeedFactory mnemonicSeedFactory,
    required WalletManagerService walletManager,
  })  : _settingsRepository = settingsRepository,
        _mnemonicSeedFactory = mnemonicSeedFactory,
        _walletManager = walletManager;

  Future<void> execute({
    required List<String> mnemonicWords,
    String? passphrase,
    required ScriptType scriptType,
    String label = '',
    required bool isDefault,
  }) async {
    final environment = await _settingsRepository.getEnvironment();
    final bitcoinNetwork =
        environment.isMainnet ? Network.bitcoinMainnet : Network.bitcoinTestnet;

    final mnemonicSeed = _mnemonicSeedFactory.fromWords(
      mnemonicWords,
      passphrase: passphrase,
    );

    if (!isDefault) {
      await _walletManager.createWallet(
        seed: mnemonicSeed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
      );

      return;
    }

    final liquidNetwork =
        environment.isMainnet ? Network.liquidMainnet : Network.liquidTestnet;

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

    return;
  }
}
