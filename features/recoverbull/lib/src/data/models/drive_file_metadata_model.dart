import 'package:googleapis/drive/v3.dart' as drive;
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

  factory DriveFileMetadataModel.fromDriveFile(drive.File file) {
    final id = file.id;
    final name = file.name;
    final created = file.createdTime;
    if (id == null || name == null || created == null) {
      throw const FormatException('Invalid Drive metadata');
    }
    return DriveFileMetadataModel(
      id: id,
      name: name,
      createdTime: created,
      modifiedTime: file.modifiedTime,
    );
  }

  DriveFileMetadata toEntity() => DriveFileMetadata(
    id: id,
    name: name,
    createdTime: createdTime,
    modifiedTime: modifiedTime,
  );
}
