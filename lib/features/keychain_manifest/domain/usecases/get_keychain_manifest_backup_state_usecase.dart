import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_state.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';

final class GetKeychainManifestBackupStateUsecase {
  final KeychainManifestBackupStateRepository repository;

  const GetKeychainManifestBackupStateUsecase(this.repository);

  Future<KeychainManifestBackupState> execute() => repository.get();

  Stream<KeychainManifestBackupState> watch() => repository.watch();
}
