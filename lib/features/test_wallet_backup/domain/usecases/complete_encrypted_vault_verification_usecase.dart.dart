import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';

class CompleteEncryptedVaultVerificationUsecase {
  final WalletRepository _walletRepository;
  CompleteEncryptedVaultVerificationUsecase({
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

      for (final defaultWallet in defaultWallets) {
        await _walletRepository.updateBackupInfo(
          isEncryptedVaultTested: true,
          isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
          latestEncryptedBackup: DateTime.now(),
          latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
          walletId: defaultWallet.id,
        );
      }
    } catch (e) {
      throw CompleteEncryptedVaultVerificationException(e.toString());
    }
  }
}

class CompleteEncryptedVaultVerificationException implements Exception {
  final String message;

  CompleteEncryptedVaultVerificationException(this.message);
}
