import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/domain/services/wallet_manager.dart';

class ImportXpubUseCase {
  final SettingsRepository _settingsRepository;
  final WalletManager _walletManager;

  ImportXpubUseCase({
    required SettingsRepository settingsRepository,
    required WalletManager walletManager,
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
