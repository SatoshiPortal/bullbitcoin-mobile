class DriveFileMetadata {
  final String id;
  final String name;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  DriveFileMetadata({
    required this.id,
    required this.name,
    required this.createdTime,
    this.modifiedTime,
  });
}
