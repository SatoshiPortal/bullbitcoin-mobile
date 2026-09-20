import 'package:async/async.dart' show StreamGroup;
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/data_backup_status.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:meta/meta.dart';

class LoadDataBackupStatusUsecase {
  final WalletBackupFacade _backups;
  const LoadDataBackupStatusUsecase(this._backups);

  @useResult
  Future<Result<DataBackupStatus, BackupSettingsFailure>> execute({
    bool retryPublication = false,
  }) async {
    final controlResult = await _backups.getControl();
    if (controlResult case Err(:final failure)) {
      return Err(BackupSettingsFailure.fromDataBackup(failure));
    }
    final control =
        (controlResult as Ok<WalletBackupControl, WalletBackupFailure>).value;
    // An undecided/off page is not permission to read the wallet seed.
    if (control.enabled == null) return Ok(DataBackupStatus(control: control));
    if (control.enabled == false) {
      final date = await _backups.getLastSuccessAt();
      return Ok(
        DataBackupStatus(
          control: control,
          lastSuccessAt: switch (date) {
            Ok(:final value) => value,
            Err() => null,
          },
        ),
      );
    }
    final stateResult = await _backups.getState();
    if (stateResult case Err(:final failure)) {
      return Ok(
        DataBackupStatus(
          control: control,
          failure: BackupSettingsFailure.fromDataBackup(failure),
        ),
      );
    }
    final state =
        (stateResult as Ok<WalletBackupState, WalletBackupFailure>).value;
    final current = WalletBackupControl(
      enabled: state.enabled,
      recoveryIncomplete: state.recoveryIncomplete,
    );
    if (current.enabled != true) {
      return Ok(
        DataBackupStatus(control: current, lastSuccessAt: state.lastSuccessAt),
      );
    }
    if (retryPublication && !current.recoveryIncomplete) {
      _backups.retryAutomatic();
    }
    final job = _backups.publicationStatus;
    return Ok(
      DataBackupStatus(
        control: current,
        lastSuccessAt: state.lastSuccessAt,
        publishing: job.running,
        publication: switch (job.result) {
          Ok(:final value) => value,
          _ => null,
        },
        failure: switch (job.result) {
          Err(:final failure) => BackupSettingsFailure.fromDataBackup(failure),
          _ => null,
        },
      ),
    );
  }
}

class WatchDataBackupStatusUsecase {
  final WalletBackupFacade _backups;
  const WatchDataBackupStatusUsecase(this._backups);
  Stream<void> execute() => StreamGroup.merge([
    _backups.watchState(),
    _backups.watchPublication().map((_) {}),
  ]);
}

class SetDataBackupEnabledUsecase {
  final WalletBackupFacade _backups;
  const SetDataBackupEnabledUsecase(this._backups);
  @useResult
  Future<Result<void, BackupSettingsFailure>> execute(bool enabled) async =>
      (await _backups.setEnabled(
        enabled,
      )).mapErr(BackupSettingsFailure.fromDataBackup);
}

class PublishDataBackupUsecase {
  final WalletBackupFacade _backups;
  const PublishDataBackupUsecase(this._backups);
  @useResult
  Future<Result<WalletBackupPublication, BackupSettingsFailure>> execute({
    WalletBackupInspection? replace,
    bool confirmed = false,
  }) async {
    if (replace != null && !confirmed) {
      return const Err(BackupSettingsConfirmationRequiredFailure());
    }
    return (await _backups.publish(
      force: true,
      replace: replace,
    )).mapErr(BackupSettingsFailure.fromDataBackup);
  }
}

class DeleteDataBackupUsecase {
  final WalletBackupFacade _backups;
  const DeleteDataBackupUsecase(this._backups);
  @useResult
  Future<Result<void, BackupSettingsFailure>> execute({
    required bool confirmed,
  }) async {
    if (!confirmed) {
      return const Err(BackupSettingsConfirmationRequiredFailure());
    }
    return (await _backups.delete(
      confirmed: confirmed,
    )).mapErr(BackupSettingsFailure.fromDataBackup);
  }
}

class LoadLocalDataBackupUsecase {
  final WalletBackupFacade _backups;
  const LoadLocalDataBackupUsecase(this._backups);
  @useResult
  Future<Result<WalletBackupSnapshot, BackupSettingsFailure>> execute() async =>
      (await _backups.capture()).mapErr(BackupSettingsFailure.fromDataBackup);
}
