import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

final class GetWalletRecoveryInventoryUsecase {
  final Future<Result<WalletBackupKey, WalletBackupFailure>> Function()
  _resolveKey;
  final Future<Result<void, WalletBackupFailure>> Function(Fingerprint)
  _refresh;
  final Future<Result<KeychainManifest, KeychainManifestFailure>> Function(
    Fingerprint,
  )
  _readManifest;

  const GetWalletRecoveryInventoryUsecase(
    this._resolveKey,
    this._refresh,
    this._readManifest,
  );

  @useResult
  Future<Result<KeychainManifest, WalletBackupFailure>> execute() async {
    final String fingerprint;
    switch (await _resolveKey()) {
      case Ok(:final value):
        fingerprint = value.parentFingerprint;
      case Err(:final failure):
        return Err(failure);
    }
    final parent = Fingerprint.tryParse(fingerprint);
    if (parent == null) {
      return const Err(WalletBackupParentFingerprintMismatchFailure());
    }
    if (await _refresh(parent) case Err(:final failure)) {
      return Err(failure);
    }
    return switch (await _readManifest(parent)) {
      Ok(:final value) => Ok(value),
      Err(:final failure) => Err(
        WalletBackupManifestFailure(failure.runtimeType.toString()),
      ),
    };
  }
}
