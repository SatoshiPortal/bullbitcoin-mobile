import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_failure.dart';

class NostrIdentityFacade {
  final GetNostrPublicKeyUsecase _getPublicKey;
  final SignNostrHashUsecase _signHash;

  const NostrIdentityFacade(this._getPublicKey, this._signHash);

  @useResult
  Future<Result<String, NostrIdentityFailure>> walletBackupPublicKey() =>
      _getPublicKey.execute();

  @useResult
  Future<Result<String, NostrIdentityFailure>> signWalletBackupHash(
    String hashHex,
  ) => _signHash.execute(hashHex);
}
