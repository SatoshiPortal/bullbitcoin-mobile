import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_key.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:mocktail/mocktail.dart';

/// Only the storage lookup is faked. Real BIP85/scoped derivation and signing run.
NostrIdentityFacade descriptorPrototypeIdentity(String rootXprv) {
  final resolver = _FixtureKeyResolver(rootXprv);
  return NostrIdentityFacade(
    GetNostrPublicKeyUsecase(resolver),
    SignNostrHashUsecase(resolver),
  );
}

class _FixtureKeyResolver extends Mock implements NostrIdentityKeyResolver {
  final String rootXprv;
  _FixtureKeyResolver(this.rootXprv);
  @override
  Future<Result<NostrKey, NostrIdentityFailure>> resolve() async => Ok(
    NostrKey.derive(
      rootXprv: rootXprv,
      path: Bip85Reservations.nostrWalletBackupKey.path,
    ),
  );
}
