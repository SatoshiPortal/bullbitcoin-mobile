abstract interface class RecoverBullDriveDiscoveryPort {
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  );
}

abstract interface class RecoverBullDriveDiscoverySession {
  String get account;
  Future<List<RecoverBullDriveFile>> files();
  Future<String> content(String fileId);
}

final class RecoverBullDriveFile {
  final String id;
  final DateTime createdTime;
  final DateTime? modifiedTime;

  const RecoverBullDriveFile({
    required this.id,
    required this.createdTime,
    this.modifiedTime,
  });
}
