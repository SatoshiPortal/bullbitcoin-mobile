import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;

  CompletePhysicalBackupVerificationUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw const NoDefaultWalletFoundError();
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

class CompletePhysicalBackupVerificationException implements Exception {
  final String message;

  CompletePhysicalBackupVerificationException(this.message);
}
