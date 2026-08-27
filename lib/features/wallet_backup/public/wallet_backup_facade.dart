export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart'
    show WalletBackupState;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart'
    show
        WalletBackupContents,
        WalletBackupWalletSummary,
        WalletBackupMetadataSummary;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart'
    show WalletBackupRecoveryResult, WalletBackupRecoveryStatus;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart'
    show WalletBackupRecoveryOutcome;
export 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery_outcome.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_recovery_outcome_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/watch_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_coordinator.dart';
import 'package:meta/meta.dart';

class WalletBackupFacade {
  final GetWalletBackupStateUsecase _getState;
  final GetWalletBackupContentsUsecase _getContents;
  final WatchWalletBackupStateUsecase _watchState;
  final SetWalletBackupEnabledUsecase _setEnabled;
  final DeleteWalletBackupUsecase _delete;
  final WalletBackupCoordinator _coordinator;
  final RecoverWalletBackupUsecase _recover;
  final GetWalletBackupRecoveryOutcomeUsecase _getRecoveryOutcome;

  const WalletBackupFacade({
    required this._getState,
    required this._getContents,
    required this._watchState,
    required this._setEnabled,
    required this._delete,
    required this._coordinator,
    required this._recover,
    required this._getRecoveryOutcome,
  });

  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> getState() {
    return _getState.execute();
  }

  @useResult
  Future<Result<WalletBackupContents, WalletBackupFailure>> getContents() {
    return _getContents.execute();
  }

  @useResult
  Stream<Result<WalletBackupState, WalletBackupFailure>> watchState() {
    return _watchState.execute();
  }

  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled) async {
    final result = await _setEnabled.execute(enabled);
    if (result case Err()) return result;
    if (!enabled) return result;
    return _coordinator.publish();
  }

  @useResult
  Future<Result<void, WalletBackupFailure>> backupNow() {
    return _coordinator.publishLatest();
  }

  @useResult
  Future<Result<void, WalletBackupFailure>> deleteRemoteBackup({
    required bool confirmed,
  }) async {
    if (!confirmed) return _delete.execute(confirmed: false);
    final lease = await _coordinator.beginDeletionLease();
    try {
      return await _delete.execute(confirmed: true);
    } finally {
      lease.close();
    }
  }

  Future<WalletBackupRecoveryResult> recover({
    Set<String> defaultCreatedWalletIds = const {},
  }) => _recover.execute(defaultCreatedWalletIds: defaultCreatedWalletIds);

  @useResult
  Future<Result<WalletBackupRecoveryOutcome?, WalletBackupFailure>>
  getLastRecoveryOutcome() => _getRecoveryOutcome.execute();
}
