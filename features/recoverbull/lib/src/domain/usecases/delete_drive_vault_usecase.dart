import 'package:primitives/primitives.dart';

import '../entities/drive_file_metadata.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';

final class DeleteDriveVaultUsecase {
  final GoogleDriveRepository _drive;
  const DeleteDriveVaultUsecase(this._drive);
  Future<Result<void, RecoverBullFailure>> execute(DriveFileMetadata file) =>
      _drive.trash(file);
}
