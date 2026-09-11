import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:meta/meta.dart';

class GetNostrPublicKeyUsecase {
  final NostrIdentityKeyResolver _resolver;

  const GetNostrPublicKeyUsecase(this._resolver);

  @useResult
  Future<Result<String, NostrIdentityFailure>> execute({
    String? descriptorLookup,
  }) async {
    if (descriptorLookup != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(descriptorLookup)) {
      return const Err(NostrIdentityInvalidHashFailure());
    }
    return (await _resolver.resolve()).map(
      (key) =>
          (descriptorLookup == null
                  ? key
                  : key.descriptorBackupScope(descriptorLookup))
              .publicKeyHex,
    );
  }
}
