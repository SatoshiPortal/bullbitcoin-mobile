import 'dart:typed_data';

export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart'
    show WalletBackupContents, WalletBackupWalletSummary;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart'
    show WalletBackupExport, WalletBackupFileProtection;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart'
    show
        WalletBackupDifference,
        WalletBackupImportComparison,
        WalletBackupImportSituation,
        WalletBackupImportSource,
        WalletBackupSnapshotSummary;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart'
    show WalletBackupRecoveryResult, WalletBackupRecoveryStatus;
export 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart'
    show WalletBackupRecoveryState, WalletBackupState;
export 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
export 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_contents.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file_comparison.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_export_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/get_wallet_backup_contents_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_enabled_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/set_wallet_backup_server_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/watch_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_job_runner.dart';
import 'package:meta/meta.dart';

/// The one entry point into Bull backup.
///
/// Every intent that touches the server is handed to the job runner, so the
/// facade never has to know what else is in flight.
class WalletBackupFacade {
  final GetWalletBackupContentsUsecase _getContents;
  final WatchWalletBackupStateUsecase _watchState;
  final SetWalletBackupEnabledUsecase _setEnabled;
  final SetWalletBackupServerUsecase _setServer;
  final DeleteWalletBackupUsecase _delete;
  final WalletBackupJobRunner _runner;
  final WalletBackupStateRepository _state;
  final RecoverWalletBackupUsecase _recover;
  final BuildWalletBackupExportUsecase _buildExport;
  final CompareWalletBackupFileUsecase _compareFile;
  final RecoverWalletBackupFileUsecase _recoverFile;

  const WalletBackupFacade(
    this._getContents,
    this._watchState,
    this._setEnabled,
    this._setServer,
    this._delete,
    this._runner,
    this._state,
    this._recover,
    this._buildExport,
    this._compareFile,
    this._recoverFile,
  );

  @useResult
  Future<Result<WalletBackupContents, WalletBackupFailure>> getContents() =>
      _getContents.execute();

  @useResult
  Stream<Result<WalletBackupState, WalletBackupFailure>> watchState() =>
      _watchState.execute();

  /// Enabling recovers the account's backup and publishes once, all inside one
  /// runner job: the recovery and the first publication must not be separated
  /// by anything else touching the server (spec 19.1).
  @useResult
  Future<Result<void, WalletBackupFailure>> setEnabled(bool enabled) =>
      _runner.run(() => _setEnabled.execute(enabled));

  @useResult
  Future<Result<void, WalletBackupFailure>> setServer(String value) =>
      _runner.run(() => _setServer.execute(value));

  /// Publishes a snapshot that includes every change committed before this
  /// call.
  ///
  /// Owners outside this database report their changes asynchronously, so an
  /// explicit "Backup now" records a revision of its own first rather than
  /// racing a stream event that has not arrived yet.
  @useResult
  Future<Result<void, WalletBackupFailure>> backupNow() async {
    if (await _state.recordLocalMutation() case Err(:final failure)) {
      return Err(failure);
    }
    return _runner.requestPublish();
  }

  @useResult
  Future<Result<void, WalletBackupFailure>> deleteRemoteBackup({
    required bool confirmed,
  }) {
    if (!confirmed) return _delete.execute(confirmed: false);
    return _runner.run(() => _delete.execute(confirmed: true));
  }

  Future<WalletBackupRecoveryResult> recover({
    Set<String> defaultCreatedWalletIds = const {},
  }) => _runRecovery(
    () => _recover.execute(defaultCreatedWalletIds: defaultCreatedWalletIds),
  );

  @useResult
  Future<Result<WalletBackupExport, WalletBackupFailure>> buildExport({
    required WalletBackupFileProtection protection,
    required bool confirmedUnencrypted,
  }) => _buildExport.execute(
    protection: protection,
    confirmedUnencrypted: confirmedUnencrypted,
  );

  @useResult
  Future<Result<WalletBackupImportComparison, WalletBackupFailure>> compareFile(
    Uint8List bytes,
  ) => _compareFile.execute(bytes);

  Future<WalletBackupRecoveryResult> recoverComparedFile({
    required Uint8List fileBytes,
    required WalletBackupImportComparison comparison,
    required WalletBackupImportSource source,
  }) => _runRecovery(
    () => _recoverFile.execute(
      fileBytes: fileBytes,
      comparison: comparison,
      source: source,
    ),
  );

  /// Recovery reports its own outcome, so a runner-level refusal — a closed
  /// rate-limit gate above all — has to be folded into the same shape.
  Future<WalletBackupRecoveryResult> _runRecovery(
    Future<WalletBackupRecoveryResult> Function() job,
  ) async => switch (await _runner.run(() async => Ok(await job()))) {
    Ok(:final value) => value,
    Err(:final failure) => WalletBackupRecoveryResult.fromFailure(failure),
  };
}
