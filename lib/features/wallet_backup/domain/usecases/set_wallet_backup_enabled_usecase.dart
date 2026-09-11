import 'package:bb_mobile/core/wallet/domain/entities/wallet_preferences.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bull_logger/bull_logger.dart';

final class SetWalletBackupEnabledUsecase {
  final WalletBackupStateRepository _repository;
  final Future<WalletBackupRecoveryResult> Function({
    List<WalletPreferences> defaultCreatedWalletPreferences,
  })
  _recover;
  final Future<Result<void, WalletBackupFailure>> Function() _register;
  final Future<Result<void, WalletBackupFailure>> Function() _publish;

  const SetWalletBackupEnabledUsecase(
    this._repository,
    this._recover,
    this._register,
    this._publish,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(
    bool enabled, {
    List<WalletPreferences> defaultCreatedWalletPreferences = const [],
  }) async {
    if (!enabled) return _repository.setEnabled(false);

    // The recovery material has to be in the manifest before anything reads a
    // snapshot from it, because reading no longer writes it. Registering ahead
    // of recovery also keeps it clear of the publication the recovery fence
    // releases when it finishes.
    if (await _register() case Err(:final failure)) {
      _logRefusal('registering recovery material', failure);
      return Err(failure);
    }

    final recovery = await _recover(
      defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
    );
    final recoveryFailure = _recoveryFailure(recovery.status);
    if (recoveryFailure != null) {
      log.warning(
        'Data Backup not enabled: server recovery ended with '
        '${recovery.status.name}',
        error: recoveryFailure.runtimeType,
      );
      return Err(recoveryFailure);
    }

    final enabledResult = await _repository.setEnabled(true);
    if (enabledResult case Err(:final failure)) {
      _logRefusal('persisting the flag', failure);
      return enabledResult;
    }
    final published = await _publish();
    if (published case Err(:final failure)) {
      _logRefusal('the first publication', failure);
    }
    return published;
  }

  // Enabling used to fail with no trace at all; the toggle just stayed off.
  void _logRefusal(String step, WalletBackupFailure failure) => log.warning(
    'Data Backup not enabled: $step failed',
    error: failure.runtimeType,
  );
}

WalletBackupFailure? _recoveryFailure(WalletBackupRecoveryStatus status) =>
    switch (status) {
      WalletBackupRecoveryStatus.noBackup ||
      WalletBackupRecoveryStatus.restored => null,
      WalletBackupRecoveryStatus.unavailable ||
      WalletBackupRecoveryStatus.timedOut =>
        const WalletBackupRemoteUnavailableFailure(),
      WalletBackupRecoveryStatus.newerVersion =>
        const WalletBackupUnsupportedEnvelopeVersionFailure(
          WalletBackupSnapshot.currentVersion + 1,
        ),
      WalletBackupRecoveryStatus.conflict =>
        const WalletBackupHeadConflictFailure(),
      WalletBackupRecoveryStatus.invalid => const WalletBackupManifestFailure(),
      WalletBackupRecoveryStatus.comparisonStale ||
      WalletBackupRecoveryStatus.partiallyRestored =>
        const WalletBackupRecoveryBlockedFailure(),
      WalletBackupRecoveryStatus.localFailure =>
        const WalletBackupStorageFailure(),
    };
