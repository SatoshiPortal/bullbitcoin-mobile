import 'package:backup_storage/backup_storage.dart';

import '../../domain/entities/drive_file_metadata.dart';

final class DriveFileMetadataModel {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  const DriveFileMetadataModel({
    required this.id,
    required this.name,
    required this.createdTime,
    this.modifiedTime,
  });

  factory DriveFileMetadataModel.fromStoredObject(StoredObject file) {
    final created = file.createdAt;
    if (created == null) {
      throw const FormatException('Invalid Drive metadata');
    }
    return DriveFileMetadataModel(
      id: file.id,
      name: file.name,
      createdTime: created,
      modifiedTime: file.modifiedAt,
    );
  }

  DriveFileMetadata toEntity() => DriveFileMetadata(
    id: id,
    name: name,
    createdTime: createdTime,
    modifiedTime: modifiedTime,
  );
}
