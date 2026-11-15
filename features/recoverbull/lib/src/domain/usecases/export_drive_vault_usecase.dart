import 'package:primitives/primitives.dart';

import '../entities/drive_file_metadata.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';
import '../repositories/vault_file_repository.dart';

final class ExportDriveVaultUsecase {
  final VaultFileRepository _files;
  final GoogleDriveRepository _drive;
  const ExportDriveVaultUsecase(this._files, this._drive);
  Future<Result<void, RecoverBullFailure>> execute(
    DriveFileMetadata file,
  ) async {
    switch (await _drive.fetchRawFile(file)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _files.export(value, file.name);
    }
  }
}
