import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_envelope.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_encryption_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_envelope_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/resolve_wallet_backup_key_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_section.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

final class SyncWalletBackupUsecase {
  final BuildWalletBackupEnvelopeUsecase _buildEnvelope;
  final ResolveWalletBackupKeyUsecase _resolveKey;
  final WalletBackupEncryptionRepository _encryption;
  final WalletBackupRemoteRepository _remote;
  final KeychainManifestFacade _keychainManifest;
  final WalletMetadataBackup? _metadata;

  const SyncWalletBackupUsecase({
    required this._buildEnvelope,
    required this._resolveKey,
    required this._encryption,
    required this._remote,
    required this._keychainManifest,
    this._metadata,
  });

  @useResult
  Future<Result<WalletBackupSyncResult, WalletBackupFailure>> execute() async {
    final WalletBackupKey backupKey;
    switch (await _resolveKey.execute()) {
      case Ok(:final value):
        backupKey = value;
      case Err(:final failure):
        return Err(failure);
    }

    final WalletBackupEnvelope local;
    switch (await _buildEnvelope.execute(
      parentFingerprint: backupKey.parentFingerprint,
      allowEmpty: true,
    )) {
      case Ok(:final value):
        local = value;
      case Err(:final failure):
        return Err(failure);
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      final WalletBackupRemoteHead current;
      switch (await _remote.fetch()) {
        case Ok(:final value):
          current = value;
        case Err(:final failure):
          return Err(failure);
      }

      final _ComposedBackup composed;
      switch (await _composeCandidate(
        local: local,
        current: current,
        key: backupKey.encryptionKey,
        parentFingerprint: backupKey.parentFingerprint,
      )) {
        case Ok(:final value):
          composed = value;
        case Err(:final failure):
          return Err(failure);
      }

      final String contentHash;
      switch (_encryption.contentHash(composed.envelope)) {
        case Ok(:final value):
          contentHash = value;
        case Err(:final failure):
          return Err(failure);
      }
      if (composed.matchesRemote) {
        return Ok(
          WalletBackupSyncResult(
            checkpoint: WalletBackupRemoteCheckpoint(
              generation: current.generation,
              etag: current.etag!,
            ),
            contentHash: contentHash,
          ),
        );
      }

      final WalletBackupCiphertext ciphertext;
      switch (_encryption.encrypt(
        envelope: composed.envelope,
        key: backupKey.encryptionKey,
      )) {
        case Ok(:final value):
          ciphertext = value;
        case Err(:final failure):
          return Err(failure);
      }
      switch (await _remote.store(current: current, ciphertext: ciphertext)) {
        case Ok(:final value):
          return Ok(
            WalletBackupSyncResult(checkpoint: value, contentHash: contentHash),
          );
        case Err(failure: WalletBackupHeadConflictFailure()) when attempt == 0:
          continue;
        case Err(:final failure):
          return Err(failure);
      }
    }
    return const Err(WalletBackupUnexpectedFailure('sync attempts exhausted'));
  }

  Future<Result<_ComposedBackup, WalletBackupFailure>> _composeCandidate({
    required WalletBackupEnvelope local,
    required WalletBackupRemoteHead current,
    required WalletBackupEncryptionKey key,
    required String parentFingerprint,
  }) async {
    final ciphertext = current.ciphertext;
    if (ciphertext == null) {
      return Ok(_ComposedBackup(local, matchesRemote: false));
    }

    final WalletBackupEnvelope remoteEnvelope;
    switch (_encryption.decrypt(
      ciphertext: ciphertext,
      key: key,
      expectedParentFingerprint: parentFingerprint,
    )) {
      case Ok(:final value):
        remoteEnvelope = value;
      case Err(:final failure):
        return Err(failure);
    }
    if (!remoteEnvelope.manifest.isCanonical) {
      return const Err(
        WalletBackupInvalidEnvelopeFailure('Non-canonical manifest section'),
      );
    }

    final fingerprint = Fingerprint.tryParse(parentFingerprint)!;
    final String mergedManifest;
    switch (_keychainManifest.mergeManifestFilePayloads(
      localPayload: local.manifest.payload,
      remotePayload: remoteEnvelope.manifest.payload,
      expectedParentFingerprint: fingerprint,
      generatedAt: local.createdAt,
    )) {
      case Ok(:final value):
        mergedManifest = value;
      case Err(:final failure):
        return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }

    final metadataResult = _metadata == null
        ? null
        : await _metadata.compose(
            parentFingerprint: parentFingerprint,
            remotePayload: remoteEnvelope.metadata?.payload,
          );
    if (metadataResult case Err(:final failure)) {
      return Err(WalletBackupManifestFailure(failure.runtimeType.toString()));
    }
    final metadataPayload = switch (metadataResult) {
      null => remoteEnvelope.metadata?.payload,
      Ok(:final value) => value,
      Err() => null,
    };
    if (mergedManifest == remoteEnvelope.manifest.payload &&
        metadataPayload == remoteEnvelope.metadata?.payload) {
      return Ok(_ComposedBackup(remoteEnvelope, matchesRemote: true));
    }
    return Ok(
      _ComposedBackup(
        WalletBackupEnvelope(
          parentFingerprint: parentFingerprint,
          createdAt: local.createdAt,
          manifest: WalletBackupManifestSection(
            payload: mergedManifest,
            parentFingerprint: parentFingerprint,
          ),
          metadata: metadataPayload == null
              ? null
              : WalletBackupMetadataSection(
                  payload: metadataPayload,
                  parentFingerprint: parentFingerprint,
                ),
        ),
        matchesRemote: false,
      ),
    );
  }
}

final class _ComposedBackup {
  final WalletBackupEnvelope envelope;
  final bool matchesRemote;

  const _ComposedBackup(this.envelope, {required this.matchesRemote});
}
