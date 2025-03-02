import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/entities/wallet.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/wallet_manager_repository.dart';

class ImportXpubUseCase {
  final SettingsRepository _settingsRepository;
  final WalletManagerRepository _walletManager;

  ImportXpubUseCase({
    required SettingsRepository settingsRepository,
    required WalletManagerRepository walletManager,
  })  : _settingsRepository = settingsRepository,
        _walletManager = walletManager;

  Future<Wallet> execute({
    required String xpub,
    required ScriptType scriptType,
    String label = '',
  }) async {
    final environment = await _settingsRepository.getEnvironment();
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
  }
}
