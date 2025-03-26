abstract class BackupKeyService {
  /// Provides methods to derive backup keys from the default seed
  /// parameters:
  /// - [path]: The BIP85 path to derive the backup key from.
  Future<String> deriveBackupKeyFromDefaultSeed({
    required String? path,
  });
}
