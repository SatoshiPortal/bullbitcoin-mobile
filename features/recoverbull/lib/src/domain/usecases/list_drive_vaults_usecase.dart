import 'package:primitives/primitives.dart';
import '../entities/drive_file_metadata.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';

final class ListDriveVaultsUsecase {
  final GoogleDriveRepository _drive;
  const ListDriveVaultsUsecase(this._drive);
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>> execute() async {
    switch (await _drive.connect()) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return _drive.fetchAllMetadata();
    }
  }
}
