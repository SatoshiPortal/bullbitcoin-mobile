import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_manifest_import.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class FetchWalletBackupManifestImportUsecase {
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final WalletBackupRemoteRepository _remote;
  final WalletBackupEncryptionRepository _encryption;
  final KeychainManifestFacade _keychainManifest;
  final WalletBackupStateRepository _state;

  const FetchWalletBackupManifestImportUsecase({
    required this._resolveKey,
    required this._remote,
    required this._encryption,
    required this._keychainManifest,
    required this._state,
  });

  @useResult
  Future<Result<WalletBackupManifestImport?, WalletBackupFailure>>
  execute() async {
    final keyResult = await _resolveKey.execute();
    final WalletBackupKey backupKey;
    switch (keyResult) {
      case Ok(:final value):
        backupKey = value;
      case Err(:final failure):
        return Err(failure);
    }
    final fetchResult = await _remote.fetch();
    final WalletBackupRemoteHead remote;
    switch (fetchResult) {
      case Ok(:final value):
        remote = value;
      case Err(:final failure):
        return Err(failure);
    }
    final ciphertext = remote.ciphertext;
    if (ciphertext == null) return const Ok(null);

    final decryptResult = _encryption.decrypt(
      ciphertext: ciphertext,
      key: backupKey.encryptionKey,
      expectedParentFingerprint: backupKey.parentFingerprint,
    );
    switch (decryptResult) {
      case Err(
        failure: final WalletBackupUnsupportedEnvelopeVersionFailure failure,
      ):
        final blockResult = await _state.blockUnsupportedVersion(
          failure.version,
        );
        if (blockResult case Err(:final failure)) return Err(failure);
        return Err(failure);
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final envelope):
        final plan = _keychainManifest.parseManifestFilePayload(
          envelope.manifest.payload,
          expectedParentFingerprint: Fingerprint.tryParse(
            backupKey.parentFingerprint,
          )!,
          allowEmpty: true,
        );
        return switch (plan) {
          Err(:final failure) => Err(
            WalletBackupManifestFailure(failure.runtimeType.toString()),
          ),
          Ok(value: final importPlan) => Ok(
            WalletBackupManifestImport(
              plan: importPlan,
              metadataPayload: envelope.metadata?.payload,
            ),
          ),
        };
    }
  }
}
