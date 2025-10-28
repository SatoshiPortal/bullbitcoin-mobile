import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

sealed class RecoverBullGoogleDriveEvent {
  const RecoverBullGoogleDriveEvent();
}

class OnFetchDriveVaults extends RecoverBullGoogleDriveEvent {
  const OnFetchDriveVaults();
}

class OnSelectDriveFileMetadata extends RecoverBullGoogleDriveEvent {
  const OnSelectDriveFileMetadata({required this.fileMetadata});
  final DriveFileMetadata fileMetadata;
}
