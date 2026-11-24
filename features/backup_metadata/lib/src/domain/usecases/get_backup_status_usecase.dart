import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_status.dart';
import '../repositories/backup_metadata_repository.dart';

final class GetBackupStatusUsecase {
  final BackupMetadataRepository _repository;

  const GetBackupStatusUsecase(this._repository);

  Future<Result<BackupRunStatus, BackupMetadataFailure>> execute() =>
      _repository.status();
}
