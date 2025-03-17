import 'package:bb_mobile/_core/domain/entities/drive_file.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class DriveFileModel {
  final String id;
  final String name;
  final DateTime createdTime;

  DriveFileModel({
    required this.id,
    required this.name,
    required this.createdTime,
  });

  factory DriveFileModel.fromDriveFile(drive.File file) {
    return DriveFileModel(
      id: file.id ?? '',
      name: file.name ?? '',
      createdTime: file.createdTime ?? DateTime.now(),
    );
  }

  DriveFile toDomain() {
    return DriveFile(
      id: id,
      name: name,
      createdTime: createdTime,
    );
  }
}
