import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/detect_liquid_script_type_usecase.dart';

class ImportWalletUsecase {
  final SeedRepository _seedRepository;
  final SettingsRepository _settingsRepository;
  final WalletRepository _wallet;
  final DetectLiquidScriptTypeUsecase _detectLiquidScriptTypeUsecase;

  ImportWalletUsecase({
    required SeedRepository seedRepository,
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
    required DetectLiquidScriptTypeUsecase detectLiquidScriptTypeUsecase,
  }) : _seedRepository = seedRepository,
       _settingsRepository = settingsRepository,
       _wallet = walletRepository,
       _detectLiquidScriptTypeUsecase = detectLiquidScriptTypeUsecase;

  Future<List<Wallet>> execute({
    required List<String> mnemonicWords,
    ScriptType scriptType = ScriptType.bip84,
    String passphrase = '',
    String? label,
  }) async {
    try {
      // Get the current environment to determine the network
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;
      final bitcoinNetwork =
          environment.isMainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;
      final liquidNetwork =
          environment.isMainnet ? Network.liquidMainnet : Network.liquidTestnet;

      final seed = await _seedRepository.createFromMnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );

      final importedWallets = <Wallet>[];

      // Create Bitcoin wallet with user-selected script type
      final bitcoinWallet = await _wallet.createWallet(
        seed: seed,
        network: bitcoinNetwork,
        scriptType: scriptType,
        isDefault: false,
        sync: false,
        label: label,
      );
      importedWallets.add(bitcoinWallet);
      log.fine('Bitcoin wallet imported: ${bitcoinWallet.derivationPath}');

      // For Liquid, check if user has legacy BIP49 (Aqua) funds
      final liquidScriptType = await _detectLiquidScriptTypeUsecase.execute(
        seed: seed,
        network: liquidNetwork,
      );

      // Create Liquid wallet with determined script type
      final liquidWallet = await _wallet.createWallet(
        seed: seed,
        network: liquidNetwork,
        scriptType: liquidScriptType,
        isDefault: false,
        sync: false,
        label: label,
      );
      importedWallets.add(liquidWallet);
      log.fine('Liquid wallet imported: ${liquidWallet.derivationPath}');

      log.fine('Wallets imported: ${importedWallets.length} total');

      return importedWallets;
    } catch (e) {
      throw ImportWalletException(e.toString());
    }
  }
}

class ImportWalletException extends BullException {
  ImportWalletException(super.message);
}
