import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class UpdateEncryptedVaultTest {
  final WalletRepository _walletRepository;

  UpdateEncryptedVaultTest({
    required WalletRepository walletRepository,
  }) : _walletRepository = walletRepository;

  Future<void> execute() async {
    try {
      final defaultWallets = await _walletRepository.getWallets(
        onlyDefaults: true,
        onlyBitcoin: true,
        environment: Environment.mainnet,
        sync: false,
      );
      if (defaultWallets.isEmpty) {
        throw Exception('No default wallet found');
      }

      final defaultWallet = defaultWallets.first;
      await _walletRepository.updateBackupInfo(
        isEncryptedVaultTested: true,
        isPhysicalBackupTested: defaultWallet.isPhysicalBackupTested,
        latestEncryptedBackup: defaultWallet.latestEncryptedBackup,
        latestPhysicalBackup: defaultWallet.latestPhysicalBackup,
        walletId: defaultWallet.id,
      );
    } catch (e) {
      throw UpdateEncryptedVaultTestException(e.toString());
    }
  }
}

class UpdateEncryptedVaultTestException implements Exception {
  final String message;

  UpdateEncryptedVaultTestException(this.message);
}
