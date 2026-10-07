import '../domain/recoverbull_drive_discovery_port.dart';
import '../domain/repositories/google_drive_repository.dart';

final class GoogleDriveBackupDiscoveryAdapter
    implements RecoverBullDriveDiscoveryPort {
  final GoogleDriveRepository repository;

  const GoogleDriveBackupDiscoveryAdapter(this.repository);

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  ) {
    return repository.withDiscoverySession((session) {
      if (session == null) return action(null);
      return action(_AdapterSession(session));
    });
  }
}

final class _AdapterSession implements RecoverBullDriveDiscoverySession {
  final GoogleDriveDiscoverySession _session;

  const _AdapterSession(this._session);

  @override
  String get account => _session.account;

  @override
  Future<List<RecoverBullDriveFile>> files() async => [
    for (final file in await _session.fetchAllMetadata())
      RecoverBullDriveFile(
        id: file.id,
        createdTime: file.createdTime,
        modifiedTime: file.modifiedTime,
      ),
  ];

  @override
  Future<String> content(String fileId) => _session.fetchRawFile(fileId);
}
