import 'package:googleapis/drive/v3.dart' as drive;

final class GoogleDriveFileMetadata {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  const GoogleDriveFileMetadata({
    required this.id,
    required this.name,
    required this.createdTime,
    this.modifiedTime,
  });
}

GoogleDriveFileMetadata decodeDriveFile(drive.File file) {
  final id = file.id;
  final name = file.name;
  final created = file.createdTime;
  if (id == null || name == null || created == null) {
    throw const FormatException('Invalid Drive metadata');
  }
  return GoogleDriveFileMetadata(
    id: id,
    name: name,
    createdTime: created,
    modifiedTime: file.modifiedTime,
  );
}
