import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_summary.dart';
import '../repositories/backup_metadata_repository.dart';

final class GetBackupSummaryUsecase {
  final BackupMetadataRepository _repository;

  const GetBackupSummaryUsecase(this._repository);

  Future<Result<BackupSummary, BackupMetadataFailure>> execute() =>
      _repository.summary();
}
