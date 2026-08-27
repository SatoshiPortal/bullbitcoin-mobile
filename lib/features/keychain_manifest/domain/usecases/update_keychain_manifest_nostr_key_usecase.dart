import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:primitives/primitives.dart';

final class UpdateKeychainManifestNostrKeyUsecase {
  final KeychainManifestRepository _repository;

  const UpdateKeychainManifestNostrKeyUsecase(this._repository);

  Future<Result<void, KeychainManifestFailure>> execute({
    required KeychainManifestEntry entry,
    required String purpose,
    String? description,
    DateTime? now,
  }) {
    final key = entry.materializations.singleOrNull;
    if (key is! KeychainManifestNostrKey ||
        key.keyKind != KeychainManifestNostrKeyKind.userGenerated) {
      return Future.value(const Err(KeychainManifestConflictFailure()));
    }
    return _repository.updateNostrMetadata(
      parentFingerprint: entry.parentFingerprint,
      entryId: entry.entryId,
      purpose: purpose,
      description: description,
      updatedAt: (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000,
    );
  }
}
