import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

/// Applies the wallet records of a recovered manifest.
///
/// Recovery decides which records it is willing to admit; this only decides how
/// an admitted record meets one already stored.
final class RestoreManifestSnapshotUsecase {
  final KeychainManifestRepository _repository;

  const RestoreManifestSnapshotUsecase(this._repository);

  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  execute(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy =
        KeychainManifestRestorePolicy.keepNewest,
  }) => _repository.restoreSnapshot(manifest, policy: policy);
}
