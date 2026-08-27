import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_public_key.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
export 'package:bb_mobile/features/nostr_identity/domain/nostr_public_key.dart';

class NostrIdentityFacade {
  final GetNostrPublicKeyUsecase _getPublicKey;
  final SignNostrHashUsecase _signHash;

  const NostrIdentityFacade(this._getPublicKey, this._signHash);

  @useResult
  Future<Result<NostrPublicKey, NostrIdentityFailure>>
  walletBackupPublicKey() =>
      _getPublicKey.execute(NostrIdentityPurpose.walletBackup);

  @useResult
  Future<Result<String, NostrIdentityFailure>> signWalletBackupHash(
    String hashHex,
  ) => _signHash.execute(NostrIdentityPurpose.walletBackup, hashHex);

  @useResult
  Future<Result<NostrPublicKey, NostrIdentityFailure>> bullnymAuthPublicKey() =>
      _getPublicKey.execute(NostrIdentityPurpose.bullnymAuth);

  @useResult
  Future<Result<String, NostrIdentityFailure>> signBullnymAuthHash(
    String hashHex,
  ) => _signHash.execute(NostrIdentityPurpose.bullnymAuth, hashHex);

  @useResult
  Future<Result<NostrPublicKey, NostrIdentityFailure>>
  nip05VerificationPublicKey() =>
      _getPublicKey.execute(NostrIdentityPurpose.nip05Verification);
}
