import '../../domain/entities/drive_file_metadata.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../../support/errors.dart';

class DriveFileMetadataModel {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  DriveFileMetadataModel({
    required this.id,
    required this.name,
    required this.createdTime,
    this.modifiedTime,
  });

  factory DriveFileMetadataModel.fromDriveFile(drive.File file) {
    if (file.id == null || file.name == null || file.createdTime == null) {
      throw InvalidDriveFileMetadataException();
    }

    return DriveFileMetadataModel(
      id: file.id!,
      name: file.name!,
      createdTime: file.createdTime!,
      modifiedTime: file.modifiedTime,
    );
  }

  DriveFileMetadata toEntity() {
    return DriveFileMetadata(
      id: id,
      name: name,
      createdTime: createdTime,
      modifiedTime: modifiedTime,
    );
  }
}

class DriveFileMetadataException extends RecoverBullDataException {
  DriveFileMetadataException(super.message);
}

class InvalidDriveFileMetadataException extends RecoverBullDataException {
  InvalidDriveFileMetadataException() : super('Invalid drive file metadata');
}
