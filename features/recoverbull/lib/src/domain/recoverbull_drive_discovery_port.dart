import 'package:primitives/primitives.dart';
import 'entities/encrypted_vault.dart';
import 'recoverbull_failure.dart';

abstract interface class RecoverBullDriveDiscoveryPort {
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  );
}

abstract interface class RecoverBullDriveDiscoverySession {
  String get account;

  /// Applies local discovery results only while this account is current.
  Future<T> withCurrentAccount<T>(Future<T> Function() action);
  Future<List<RecoverBullDriveFile>> files();
  Future<Result<EncryptedVault, RecoverBullFailure>> content(String fileId);
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
