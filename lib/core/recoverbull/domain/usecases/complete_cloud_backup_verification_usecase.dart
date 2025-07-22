import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CompleteCloudBackupVerificationUsecase {
  final WalletRepository _walletRepository;

  CompleteCloudBackupVerificationUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      // There should only be one default Bitcoin wallet

      for (final defaultWallet in defaultWallets) {
        await _walletRepository.updateBackupInfo(
          walletId: defaultWallet.id,
          isEncryptedVaultTested: true,
          isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
          latestEncryptedBackup: DateTime.now(),
          latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
        );
      }
    } catch (e) {
      throw CompleteCloudBackupVerificationException(e.toString());
    }
  }
}

class CompleteCloudBackupVerificationException implements Exception {
  final String message;

  CompleteCloudBackupVerificationException(this.message);
}
