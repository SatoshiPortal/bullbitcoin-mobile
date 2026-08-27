import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_public_key.dart';
import 'package:meta/meta.dart';

class GetNostrPublicKeyUsecase {
  final NostrIdentityKeyResolver _resolver;

  const GetNostrPublicKeyUsecase(this._resolver);

  @useResult
  Future<Result<NostrPublicKey, NostrIdentityFailure>> execute(
    NostrIdentityPurpose purpose,
  ) async => (await _resolver.resolve(
    purpose,
  )).map((key) => NostrPublicKey(hex: key.publicKeyHex, npub: key.npub));
}
