import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CompletePhysicalBackupVerificationUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  Future<void> execute({String? fingerprint}) async {
    try {
      final wallets = fingerprint == null
          ? await _defaultWallets()
          : await _walletRepository.getWallets(onlyBitcoin: true);
      final normalizedFingerprint = fingerprint?.toLowerCase();
      final matchingWallets = normalizedFingerprint == null
          ? wallets
          : wallets
                .where(
                  (wallet) =>
                      wallet.singleLocalSeedFingerprint ==
                      normalizedFingerprint,
                )
                .toList();
      if (matchingWallets.isEmpty) {
        throw Exception('No wallet found for physical backup verification');
      }

      for (final wallet in matchingWallets) {
        await _walletRepository.updateBackupInfo(
          walletId: wallet.id,
          isEncryptedVaultTested: wallet.isEncryptedVaultTested,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: wallet.latestEncryptedBackup,
          latestPhysicalBackup: DateTime.now(),
        );
      }
    } catch (e) {
      throw CompletePhysicalBackupVerificationException(e.toString());
    }
  }

  Future<List<Wallet>> _defaultWallets() async {
    final settings = await _settingsRepository.fetch();
    return _walletRepository.getWallets(
      onlyDefaults: true,
      environment: settings.environment,
    );
  }
}

class CompletePhysicalBackupVerificationException extends BullException {
  CompletePhysicalBackupVerificationException(super.message);
}
