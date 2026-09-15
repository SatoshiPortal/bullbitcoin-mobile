import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Records the invariant recovery material every published snapshot carries:
/// the seed-derived wallet inventory and the backup credential's two
/// identities.
///
/// This is the write that used to happen inside snapshot construction. It runs
/// when the feature starts and when the user enables backup, so that taking a
/// snapshot mutates nothing and emits no manifest change.
///
/// The identities are recorded as two-step BIP85 chains, so the manifest states
/// the instruction in full: the first step derives the twelve backup words from
/// the seed, the second is applied to the words' own BIP39 root. The manifest
/// re-derives each key by that instruction before recording it, so the
/// credential and the manifest can never disagree silently. The encryption key
/// is the third child of the words and has no public form to record.
final class RegisterWalletBackupRecoveryMaterialUsecase {
  static const artifactIdentityPurpose = 'Data backup: public artifact key';
  static const serverIdentityPurpose = 'Data backup: server account key';
  static const identityDescription =
      'Two BIP85 steps in sequence: the first derives the twelve backup words '
      'from the seed; their BIP39 seed with no passphrase is the root of the '
      'second, whose first 32 bytes are this key.';

  final ResolveWalletBackupKeyUsecase _resolveKey;
  final RefreshWalletRecoveryManifestUsecase _refreshManifest;
  final NostrIdentityFacade _identity;
  final KeychainManifestFacade _manifest;
  final DateTime Function() _nowUtc;

  const RegisterWalletBackupRecoveryMaterialUsecase(
    this._resolveKey,
    this._refreshManifest,
    this._identity,
    this._manifest, {
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
    if (await _refreshManifest.execute(fingerprint) case Err(:final failure)) {
      return Err(failure);
    }
    final identities = [
      (
        Bip85Reservations.backupArtifactIdentityChain,
        artifactIdentityPurpose,
        await _identity.walletBackupPublicKey(),
      ),
      (
        Bip85Reservations.backupServerIdentityChain,
        serverIdentityPurpose,
        await _identity.walletBackupServerPublicKey(),
      ),
    ];
    for (final (chain, purpose, publicKey) in identities) {
      final String publicKeyHex;
      switch (publicKey) {
        case Ok(:final value):
          publicKeyHex = value;
        case Err():
          return const Err(WalletBackupKeyDerivationFailure());
      }
      final recorded = await _manifest.recordDerivedNostrKey(
        reservationId: Bip85Reservations.backupWords.id,
        parentFingerprint: fingerprint,
        derivationKind: KeychainManifestDerivationKind.bip85Chain,
        derivationPath: KeychainManifestEntry.chainPath(chain),
        publicKeyHex: publicKeyHex,
        purpose: purpose,
        description: identityDescription,
        now: _nowUtc(),
      );
      if (recorded case Err(:final failure)) {
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
      }
    }
    return const Ok(null);
  }
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
