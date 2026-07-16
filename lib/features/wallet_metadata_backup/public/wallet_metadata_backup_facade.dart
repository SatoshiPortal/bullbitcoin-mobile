export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_apply.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
export 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/delete_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/get_wallet_metadata_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/mark_wallet_metadata_backup_dirty_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/set_wallet_metadata_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/watchers/wallet_metadata_backup_coordinator.dart';
import 'package:meta/meta.dart';

class WalletMetadataBackupFacade {
  final GetWalletMetadataBackupStateUsecase _getState;
  final SetWalletMetadataBackupEnabledUsecase _setEnabled;
  final MarkWalletMetadataBackupDirtyUsecase _markDirty;
  final DeleteWalletMetadataBackupUsecase _deleteRemote;
  final WalletMetadataBackupCoordinator _coordinator;

  const WalletMetadataBackupFacade(
    this._getState,
    this._setEnabled,
    this._markDirty,
    this._deleteRemote,
    this._coordinator,
  );

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  getState() => _getState.execute();

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  setEnabled(bool enabled) async {
    final result = enabled
        ? await _setEnabled.execute(true)
        : await _coordinator.suppressPublicationWhile(
            () => _setEnabled.execute(false),
          );
    if (result case Ok(value: WalletMetadataBackupState(enabled: true))) {
      _coordinator.scheduleFallbackRetry();
    }
    return result;
  }

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  markDirty() => _markDirty.execute();

  @useResult
  Future<Result<WalletMetadataPublishOutcome, WalletMetadataBackupFailure>>
  backupNow() => _coordinator.publishNow();

  @useResult
  Future<Result<void, WalletMetadataBackupFailure>> deleteRemoteBackup() {
    return _coordinator.suppressPublicationWhile(_deleteRemote.execute);
  }

  Future<void> retryPendingBackup() => _coordinator.retryBestEffort();
}
