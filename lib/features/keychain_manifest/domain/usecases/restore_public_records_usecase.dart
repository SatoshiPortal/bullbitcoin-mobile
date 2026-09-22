import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:meta/meta.dart';

final class RestorePublicRecordsUsecase {
  final KeychainManifestRepository _repository;

  const RestorePublicRecordsUsecase(this._repository);

  @useResult
  Future<Result<void, KeychainManifestFailure>> execute(
    KeychainManifest manifest,
  ) => _repository.restorePublicRecords(manifest);
}
