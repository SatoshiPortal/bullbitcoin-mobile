import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_job_status.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_snapshot.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_watcher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_inspection.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_bullvault_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/vault_backup_recovery.dart';

export '../domain/entities/wallet_backup_file.dart';
export '../domain/entities/wallet_backup_file_comparison.dart';
export '../domain/entities/vault_backup_recovery.dart';
export '../domain/entities/wallet_backup_publication.dart';
export '../domain/entities/wallet_backup_job_status.dart';
export '../domain/entities/bullvault_backup_entry.dart';
export '../domain/entities/wallet_backup_inspection.dart';
export '../domain/entities/wallet_backup_recovery.dart';
export '../domain/entities/wallet_inventory_recovery.dart';
export '../domain/entities/wallet_backup_remote_head.dart';
export '../domain/entities/wallet_backup_snapshot.dart';
export '../domain/entities/wallet_backup_state.dart';
export '../domain/wallet_backup_failure.dart';

class WalletBackupFacade {
  final GetWalletBackupControlUsecase _getControl;
  final InspectWalletBackupUsecase _inspect;
  final RecoverWalletBackupUsecase _recover;
  final RestoreBullVaultBackupUsecase _recoverVaults;

  final WatchWalletBackupStateUsecase _watchState;
  final WalletBackupWatcher _watcher;

  final GetWalletBackupStateUsecase _getState;
  final SetWalletBackupEnabledUsecase _setEnabled;
  final PublishWalletBackupUsecase _publish;
  final DeleteWalletBackupUsecase _delete;
  final BuildWalletBackupSnapshotUsecase _capture;

  final PickWalletBackupFileUsecase _pickFile;

  final ExportWalletBackupFileUsecase _exportFile;

  final CompareWalletBackupFileUsecase _compareFile;

  final RecoverWalletBackupFileUsecase _recoverFile;

  const WalletBackupFacade({
    required this._recoverFile,
    required this._compareFile,
    required this._exportFile,
    required this._pickFile,
    required this._getControl,
    required this._inspect,
    required this._recover,
    required this._recoverVaults,
    required this._getState,
    required this._setEnabled,
    required this._publish,
    required this._delete,
    required this._capture,
    required this._watchState,
    required this._watcher,
  });

  void resumeAutomatic() => _watcher.resume();
  Future<void> stopAutomatic() => _watcher.stop();

  WalletBackupJobStatus get publicationStatus => _watcher.status;
  Stream<WalletBackupJobStatus> watchPublication() => _watcher.statuses;
  Stream<void> watchState() => _watchState.execute();

  @useResult
  Future<Result<String?, WalletBackupFailure>> pickFile() =>
      _pickFile.execute();
  @useResult
  Future<Result<bool, WalletBackupFailure>> exportFile(
    WalletBackupFileFormat format, {
    bool confirmed = false,
  }) => _exportFile.execute(format, confirmed: confirmed);
  @useResult
  Future<Result<WalletBackupFileComparison, WalletBackupFailure>> compareFile(
    String source,
  ) => _compareFile.execute(source);
  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> recoverFile(
    String file, {
    required WalletBackupFileComparison comparison,
    required WalletBackupImportSource source,
    required bool confirmed,
  }) => _recoverFile.execute(
    file,
    comparison: comparison,
    source: source,
    confirmed: confirmed,
  );

  @useResult
  Future<Result<WalletBackupState, WalletBackupFailure>> getState() =>
      _getState.execute();
  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(
    bool enabled, {
    bool onlyIfUndecided = false,
  }) => _setEnabled.execute(enabled, onlyIfUndecided: onlyIfUndecided);
  @useResult
  Future<Result<WalletBackupPublication, WalletBackupFailure>> publish({
    bool force = false,
    WalletBackupInspection? replace,
  }) => _publish.execute(force: force, replace: replace);
  @useResult
  Future<Result<void, WalletBackupFailure>> delete({required bool confirmed}) =>
      _delete.execute(confirmed: confirmed);
  @useResult
  Future<Result<WalletBackupSnapshot, WalletBackupFailure>> capture() =>
      _capture.execute();

  @useResult
  Future<Result<VaultBackupRecovery?, WalletBackupFailure>> recoverVaults({
    String? words,
    bool Function()? abandoned,
  }) => _recoverVaults.execute(words: words, abandoned: abandoned);

  @useResult
  Future<Result<WalletBackupRecovery, WalletBackupFailure>> recover(
    WalletBackupInspection inspection, {
    bool enableAfterRecovery = false,
    Map<String, String?> initialWalletLabels = const {},
    String? words,
  }) => _recover.execute(
    inspection,
    words: words,
    enableAfterRecovery: enableAfterRecovery,
    initialWalletLabels: initialWalletLabels,
  );

  @useResult
  Future<Result<WalletBackupControl, WalletBackupFailure>> getControl() =>
      _getControl.execute();

  @useResult
  Future<Result<WalletBackupInspection, WalletBackupFailure>> inspect({
    String? words,
  }) => _inspect.execute(words: words);
}
