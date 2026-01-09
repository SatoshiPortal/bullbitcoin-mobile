import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';

sealed class RecoverBullGoogleDriveEvent {
  const RecoverBullGoogleDriveEvent();
}

class OnFetchDriveVaults extends RecoverBullGoogleDriveEvent {
  const OnFetchDriveVaults();
}

class OnSelectDriveFileMetadata extends RecoverBullGoogleDriveEvent {
  const OnSelectDriveFileMetadata({
    required this.fileMetadata,
  });
  final DriveFileMetadata fileMetadata;
}

class OnDeleteDriveFile extends RecoverBullGoogleDriveEvent {
  const OnDeleteDriveFile({
    required this.fileMetadata,
  });
  final DriveFileMetadata fileMetadata;
}

class OnExportDriveFile extends RecoverBullGoogleDriveEvent {
  const OnExportDriveFile({
    required this.fileMetadata,
  });
  final DriveFileMetadata fileMetadata;
}
