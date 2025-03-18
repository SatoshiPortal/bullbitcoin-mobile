import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/services/wallet_manager_service.dart';

class ImportXpubUsecase {
  final SettingsRepository _settings;
  final WalletManagerService _walletManager;

  ImportXpubUsecase({
    required SettingsRepository settingsRepository,
    required WalletManagerService walletManagerService,
  })  : _settings = settingsRepository,
        _walletManager = walletManagerService;

  Future<Wallet> execute({
    required String xpub,
    required ScriptType scriptType,
    String label = '',
  }) async {
    try {
      final environment = await _settings.getEnvironment();
      final bitcoinNetwork = environment == Environment.mainnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;

      final wallet = await _walletManager.importWatchOnlyWallet(
        xpub: xpub,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
      );

      return wallet;
    } catch (e) {
      throw ImportXpubException(e.toString());
    }
  }
}

class ImportXpubException implements Exception {
  final String message;

  ImportXpubException(this.message);
}
