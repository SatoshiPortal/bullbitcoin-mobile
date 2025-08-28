import 'package:bb_mobile/core/recoverbull/domain/entity/drive_file_metadata.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFileMetadataModel {
  final String id;
  final String name;
  final DateTime createdTime;

  DriveFileMetadataModel({
    required this.id,
    required this.name,
    required this.createdTime,
  });

  factory DriveFileMetadataModel.fromDriveFile(drive.File file) {
    if (file.id == null || file.name == null || file.createdTime == null) {
      throw InvalidDriveFileMetadataException();
    }

    return DriveFileMetadataModel(
      id: file.id!,
      name: file.name!,
      createdTime: file.createdTime!,
    );
  }

  DriveFileMetadata toEntity() {
    return DriveFileMetadata(id: id, name: name, createdTime: createdTime);
  }
}

class DriveFileMetadataException implements Exception {
  final String message;

  DriveFileMetadataException(this.message);
}

class InvalidDriveFileMetadataException extends DriveFileMetadataException {
  InvalidDriveFileMetadataException() : super('Invalid drive file metadata');
}
