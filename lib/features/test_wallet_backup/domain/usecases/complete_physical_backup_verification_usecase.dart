import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;

  CompletePhysicalBackupVerificationUsecase({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyBitcoin: true,
        onlyDefaults: true,
        environment: Environment.mainnet,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }
      // There should only be one default Bitcoin wallet
      final defaultWallet = defaultWallets.first;

      await _walletRepository.updateBackupInfo(
        walletId: defaultWallet.id,
        isEncryptedVaultTested: defaultWallet.isEncryptedVaultTested,
        isPhysicalBackupTested: true,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: DateTime.now(),
      );
    } catch (e) {
      throw CompletePhysicalBackupVerificationException(e.toString());
    }
  }
}

class CompletePhysicalBackupVerificationException implements Exception {
  final String message;

  CompletePhysicalBackupVerificationException(this.message);
}
