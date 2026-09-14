import 'package:bb_mobile/features/wallet_backup/domain/usecases/refresh_wallet_recovery_manifest_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Records the invariant recovery material every published snapshot carries:
/// the seed-derived wallet inventory.
///
/// This is the write that used to happen inside snapshot construction. It runs
/// when the feature starts and when the user enables backup, so that taking a
/// snapshot mutates nothing and emits no manifest change.
///
/// The backup identity is no longer part of it: it comes from the twelve backup
/// words rather than from a BIP85 path, so the keychain manifest — an inventory
/// of path-derived keys that can be revealed as an `nsec` — is not where it
/// belongs. The protected words reveal is what tells the user about it.
final class RegisterWalletBackupRecoveryMaterialUsecase {
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final RefreshWalletRecoveryManifestUsecase _refreshManifest;

  const RegisterWalletBackupRecoveryMaterialUsecase(
    this._resolveKey,
    this._refreshManifest,
  );

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
    return _refreshManifest.execute(fingerprint);
  }
}
