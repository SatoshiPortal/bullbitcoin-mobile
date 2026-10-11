import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:meta/meta.dart';

final class GetNostrSecretUsecase {
  final NostrIdentityFacade _identities;
  const GetNostrSecretUsecase(this._identities);

  @useResult
  Future<Result<Secret, KeychainManifestFailure>> execute({
    required String expectedFingerprint,
  }) async {
    switch (await _identities.defaultSecret()) {
      case Err():
        return const Err(KeychainManifestSeedFailure());
      case Ok(:final value):
        if (value.id.hex != expectedFingerprint) {
          return const Err(KeychainManifestInvalidKeyFailure());
        }
        return Ok(value);
    }
  }
}
