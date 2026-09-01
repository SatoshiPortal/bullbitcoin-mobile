import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

DateTime _systemNowUtc() => DateTime.now().toUtc();

/// Records the invariant recovery material every published snapshot carries:
/// the reserved backup Nostr key, and the seed-derived wallet inventory.
///
/// These are the two writes that used to happen inside snapshot construction.
/// They run when the feature starts and when the user enables backup, so that
/// taking a snapshot mutates nothing and emits no manifest change (spec F5).
final class RegisterWalletBackupRecoveryMaterialUsecase {
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final NostrIdentityFacade _nostrIdentity;
  final KeychainManifestFacade _keychainManifest;
  final RefreshWalletRecoveryManifestUsecase _refreshManifest;
  final DateTime Function() _nowUtc;

  const RegisterWalletBackupRecoveryMaterialUsecase(
    this._resolveKey,
    this._nostrIdentity,
    this._keychainManifest,
    this._refreshManifest, {
    this._nowUtc = _systemNowUtc,
  });

  @useResult
  Future<Result<void, WalletBackupFailure>> execute() async {
    final Fingerprint fingerprint;
    switch (await _resolveKey.execute()) {
      case Ok(:final value):
        final parsed = Fingerprint.tryParse(value.parentFingerprint);
        if (parsed == null) {
          return const Err(WalletBackupParentFingerprintMismatchFailure());
        }
        fingerprint = parsed;
      case Err(:final failure):
        return Err(failure);
    }

    final String publicKey;
    switch (await _nostrIdentity.walletBackupPublicKey()) {
      case Ok(:final value):
        publicKey = value;
      case Err():
        return const Err(WalletBackupSigningFailure());
    }

    if (await _keychainManifest.recordWalletBackupNostrKey(
          parentFingerprint: fingerprint,
          publicKeyHex: publicKey,
          now: _nowUtc(),
        )
        case Err(:final failure)) {
      return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }
    return _refreshManifest.execute(fingerprint);
  }
}
