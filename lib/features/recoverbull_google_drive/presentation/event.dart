import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:flutter/material.dart';

sealed class RecoverBullGoogleDriveEvent {
  const RecoverBullGoogleDriveEvent();
}

class OnFetchDriveVaults extends RecoverBullGoogleDriveEvent {
  const OnFetchDriveVaults({this.context});
  final BuildContext? context;
}

class OnSelectDriveFileMetadata extends RecoverBullGoogleDriveEvent {
  const OnSelectDriveFileMetadata({
    required this.fileMetadata,
    this.context,
  });
  final DriveFileMetadata fileMetadata;
  final BuildContext? context;
}

class OnDeleteDriveFile extends RecoverBullGoogleDriveEvent {
  const OnDeleteDriveFile({
    required this.fileMetadata,
    this.context,
  });
  final DriveFileMetadata fileMetadata;
  final BuildContext? context;
}

class OnExportDriveFile extends RecoverBullGoogleDriveEvent {
  const OnExportDriveFile({
    required this.fileMetadata,
    this.context,
  });
  final DriveFileMetadata fileMetadata;
  final BuildContext? context;
}
