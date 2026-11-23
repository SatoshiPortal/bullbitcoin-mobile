import 'package:googleapis/drive/v3.dart' as drive;

final class GoogleDriveFileMetadata {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime? modifiedTime;
  final int? size;
  final String? md5;

  const GoogleDriveFileMetadata({
    required this.id,
    required this.name,
    required this.createdTime,
    this.modifiedTime,
    this.size,
    this.md5,
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
    size: int.tryParse(file.size ?? ''),
    md5: file.md5Checksum,
  );
}
