import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads from the wallet repo directly so callers can verify backup state
/// against the DB rather than a potentially-stale bloc cache.
class CheckBackupNeededUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Future<RecoverBullStatus> Function() _recoverBullStatus;

  CheckBackupNeededUsecase({
    required this._walletRepository,
    required this._settingsRepository,
    required this._recoverBullStatus,
  });

  @useResult
  Future<Result<bool, WalletFailure>> execute() async {
    final Environment environment;
    try {
      environment = (await _settingsRepository.fetch()).environment;
    } catch (e, st) {
      log.severe(message: 'CheckBackupNeeded: settings', error: e, trace: st);
      return Err(WalletStorageFailure('settings fetch: ${e.runtimeType}'));
    }

    final List<Wallet> defaultWallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: environment,
    )) {
      case Ok(:final value):
        defaultWallets = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (defaultWallets.isEmpty) return const Ok(false);

    final status = await _recoverBullStatus();
    // An unreadable encrypted-backup status must not hide the warning: fall
    // back to the physical backup alone, which is still known from the DB.
    if (!status.isKnown) {
      log.warning(
        'CheckBackupNeeded: RecoverBull status unavailable, '
        'evaluating the physical backup only',
      );
    }
    final hasVerifiedEncryptedBackup =
        status.isKnown && status.hasVerifiedEncryptedBackup;
    return Ok(
      defaultWallets.any(
        (wallet) =>
            !hasVerifiedEncryptedBackup && !wallet.isPhysicalBackupTested,
      ),
    );
  }
}
