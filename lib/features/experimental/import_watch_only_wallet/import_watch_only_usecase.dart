import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class ImportWatchOnlyUsecase {
  final SettingsRepository _settings;
  final WalletRepository _wallet;

  ImportWatchOnlyUsecase({
    required SettingsRepository settingsRepository,
    required WalletRepository walletRepository,
  }) : _settings = settingsRepository,
       _wallet = walletRepository;

  Future<Wallet> call({
    required String extendedPublicKey,
    required ScriptType scriptType,
    String label = '',
    String? overrideFingerprint,
  }) async {
    try {
      final settings = await _settings.fetch();
      final environment = settings.environment;
      final bitcoinNetwork =
          environment == Environment.mainnet
              ? Network.bitcoinMainnet
              : Network.bitcoinTestnet;

      final wallet = await _wallet.importWatchOnlyWallet(
        xpub: extendedPublicKey,
        network: bitcoinNetwork,
        scriptType: scriptType,
        label: label,
        overrideFingerprint: overrideFingerprint,
      );

      return wallet;
    } catch (e) {
      throw ImportWatchOnlyException(e.toString());
    }
  }
}

class ImportWatchOnlyException implements Exception {
  final String message;

  ImportWatchOnlyException(this.message);
}
