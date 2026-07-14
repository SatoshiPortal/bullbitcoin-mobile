import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:meta/meta.dart';

class CompletePhysicalBackupVerificationUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CompletePhysicalBackupVerificationUsecase(
    this._walletRepository,
    this._settingsRepository,
  );

  @useResult
  Future<Result<void, TestWalletBackupFailure>> execute({
    required String masterFingerprint,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final wallets = await _walletRepository.getWallets(
        environment: settings.environment,
      );
      final backedUpWallets = wallets
          .where((wallet) => wallet.masterFingerprint == masterFingerprint)
          .toList();
      if (backedUpWallets.isEmpty) {
        return const Err(
          TestWalletBackupPersistenceFailure(
            'No wallets match the verified physical backup',
          ),
        );
      }

      final completedAt = DateTime.now();
      for (final wallet in backedUpWallets) {
        await _walletRepository.updateBackupInfo(
          walletId: wallet.id,
          isEncryptedVaultTested: wallet.isEncryptedVaultTested,
          isPhysicalBackupTested: true,
          latestEncryptedBackup: wallet.latestEncryptedBackup,
          latestPhysicalBackup: completedAt,
        );
      }
      return const Ok(null);
    } on WalletError catch (e, st) {
      return _failure(e, st);
    } on Exception catch (e, st) {
      return _failure(e, st);
    }
  }

  Err<void, TestWalletBackupFailure> _failure(Object error, StackTrace trace) {
    log.severe(
      message: 'completePhysicalBackupVerification failed',
      error: error,
      trace: trace,
    );
    return Err(TestWalletBackupPersistenceFailure(error.toString()));
  }
}
