import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:meta/meta.dart';

class SignNostrHashUsecase {
  static final _hashPattern = RegExp(r'^[0-9a-fA-F]{64}$');

  final NostrIdentityKeyResolver _resolver;

  const SignNostrHashUsecase(this._resolver);

  @useResult
  Future<Result<String, NostrIdentityFailure>> execute(
    String hashHex, {
    String? descriptorLookup,
    String? expectedPublicKey,
  }) async {
    if (!_hashPattern.hasMatch(hashHex) ||
        (descriptorLookup != null &&
            (!RegExp(r'^[0-9a-f]{64}$').hasMatch(descriptorLookup) ||
                expectedPublicKey == null))) {
      return const Err(NostrIdentityInvalidHashFailure());
    }
    final result = await _resolver.resolve();
    switch (result) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final key = descriptorLookup == null
            ? value
            : value.descriptorBackupScope(descriptorLookup);
        if (expectedPublicKey != null &&
            key.publicKeyHex != expectedPublicKey) {
          return const Err(NostrIdentityUnavailableFailure());
        }
        return Ok(key.signHash(hashHex));
    }
  }
}
