import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CompleteEncryptedVaultVerificationUsecase {
  final WalletRepository _walletRepository;
  CompleteEncryptedVaultVerificationUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }

      // There should only be one default Bitcoin wallet
      final defaultWallet = defaultWallets.first;
      await _walletRepository.updateBackupInfo(
        isEncryptedVaultTested: true,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
        walletId: defaultWallet.id,
      );
    } catch (e) {
      throw CompleteEncryptedVaultVerificationException(e.toString());
    }
  }
}

class CompleteEncryptedVaultVerificationException implements Exception {
  final String message;

  CompleteEncryptedVaultVerificationException(this.message);
}
