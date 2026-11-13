import 'package:primitives/primitives.dart';
import '../entities/backup_status.dart';
import '../entities/vault_context.dart';
import '../recoverbull_failure.dart';
import '../repositories/backup_metadata_repository.dart';

final class ReadBackupStatusUsecase {
  final BackupMetadataRepository? _metadata;
  final RecoverBullFailure unavailable;
  const ReadBackupStatusUsecase(this._metadata, this.unavailable);

  Future<Result<BackupStatus, RecoverBullFailure>> execute(
    VaultContext context,
  ) => _metadata?.status(context) ?? Future.value(Err(unavailable));
}
