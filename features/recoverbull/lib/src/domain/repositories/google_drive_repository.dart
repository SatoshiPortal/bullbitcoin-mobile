import 'package:primitives/primitives.dart';

import '../entities/drive_file_metadata.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';

abstract interface class GoogleDriveRepository {
  Future<T> withDiscoverySession<T>(
    Future<T> Function(GoogleDriveDiscoverySession? session) action,
  );
  Future<Result<Null, RecoverBullFailure>> connect();
  Future<String?> connectSilently();
  Future<void> disconnect();
  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>>
  fetchAllMetadata();
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchVault(String fileId);
  Future<Result<String, RecoverBullFailure>> fetchRawFile(String fileId);
  Future<Result<EncryptedVault, RecoverBullFailure>> fetchLatestVault();
  Future<Result<Null, RecoverBullFailure>> store(String content);
  Future<Result<Null, RecoverBullFailure>> trash(String fileId);
}

abstract interface class GoogleDriveDiscoverySession {
  String get account;
  Future<List<DriveFileMetadata>> fetchAllMetadata();
  Future<String> fetchRawFile(String fileId);
}
