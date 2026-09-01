import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class SetWalletBackupEnabledUsecase {
  final WalletBackupStateRepository _repository;
  final Future<WalletBackupRecoveryResult> Function() _recover;
  final Future<Result<void, WalletBackupFailure>> Function() _register;
  final Future<Result<void, WalletBackupFailure>> Function() _publish;

  const SetWalletBackupEnabledUsecase(
    this._repository,
    this._recover,
    this._register,
    this._publish,
  );

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(bool enabled) async {
    if (!enabled) return _repository.setEnabled(false);

    // The recovery material has to be in the manifest before anything reads a
    // snapshot from it, because reading no longer writes it. Registering ahead
    // of recovery also keeps it clear of the publication the recovery fence
    // releases when it finishes.
    if (await _register() case Err(:final failure)) return Err(failure);

    final recovery = await _recover();
    final recoveryFailure = _recoveryFailure(recovery.status);
    if (recoveryFailure != null) return Err(recoveryFailure);

    final enabledResult = await _repository.setEnabled(true);
    if (enabledResult case Err()) return enabledResult;
    return _publish();
  }
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
