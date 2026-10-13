import 'package:primitives/primitives.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import 'mappers/encrypted_vault_mapper.dart';
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
  Future<T> withCurrentAccount<T>(Future<T> Function() action) =>
      _session.withCurrentAccount(action);

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
  Future<Result<EncryptedVault, RecoverBullFailure>> content(
    String fileId,
  ) async {
    final String content;
    try {
      content = await _session.fetchRawFile(fileId);
    } on Exception {
      return const Err(
        RecoverBullGoogleDriveFetchFailure('Drive fetch failed'),
      );
    }
    try {
      return Ok(EncryptedVaultMapper.parse(content));
    } on Exception {
      return const Err(InvalidVaultFileFailure());
    }
  }
}
