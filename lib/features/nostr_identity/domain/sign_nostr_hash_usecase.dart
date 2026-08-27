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
    NostrIdentityPurpose purpose,
    String hashHex,
  ) async {
    if (!_hashPattern.hasMatch(hashHex)) {
      return const Err(NostrIdentityInvalidHashFailure());
    }
    return (await _resolver.resolve(
      purpose,
    )).map((key) => key.signHash(hashHex));
  }
}
