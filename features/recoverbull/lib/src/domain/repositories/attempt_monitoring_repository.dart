import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/attempt_observation.dart';
import '../entities/backup_monitoring.dart';
import '../entities/backup_settings.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';

abstract interface class AttemptMonitoringRepository {
  Stream<Result<BackupMonitoring, RecoverBullFailure>> watchStatus();

  @useResult
  Future<Result<void, RecoverBullFailure>> register(
    BackupSettings settings,
    EncryptedVault vault,
  );
  @useResult
  Future<Result<OwnBackupOperation, RecoverBullFailure>> begin(
    BackupSettings settings,
    EncryptedVault vault,
  );
  @useResult
  Future<Result<void, RecoverBullFailure>> complete(
    OwnBackupOperation operation, {
    AttemptObservation? observation,
    bool lockout = false,
    bool trashed = false,
  });
  @useResult
  Future<Result<MonitoringCheck?, RecoverBullFailure>> prepare();
  @useResult
  Future<Result<void, RecoverBullFailure>> observe(
    MonitoringCheck check,
    AttemptSnapshot? snapshot,
  );
  @useResult
  Future<Result<BackupMonitoring, RecoverBullFailure>> status();
  @useResult
  Future<Result<void, RecoverBullFailure>> acknowledge(int acknowledgement);
}
