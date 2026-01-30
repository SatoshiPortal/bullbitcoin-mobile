import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CompletePhysicalBackupVerificationUsecase({
    required WalletRepository walletRepository,
    required SettingsRepository settingsRepository,
  }) : _walletRepository = walletRepository,
       _settingsRepository = settingsRepository;

  Future<void> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: settings.environment,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      // There should only be one default Bitcoin wallet

      for (final defaultWallet in defaultWallets) {
        await _walletRepository.updateBackupInfo(
          walletId: defaultWallet.id,
          isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
          latestPhysicalBackup: DateTime.now(),
        );
      }
    } catch (e) {
      throw CompletePhysicalBackupVerificationException(e.toString());
    }
  }
}

class CompletePhysicalBackupVerificationException extends BullException {
  CompletePhysicalBackupVerificationException(super.message);
}
