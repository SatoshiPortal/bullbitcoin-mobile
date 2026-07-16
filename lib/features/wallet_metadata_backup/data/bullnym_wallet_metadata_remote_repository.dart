import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:meta/meta.dart';

final class BullnymWalletMetadataRemoteRepository
    implements WalletMetadataRemoteRepository {
  final BullnymFacade _bullnym;
  final WalletMetadataSnapshotCryptor _snapshots;
  final NostrIdentityFacade _identity;
  final WalletMetadataSnapshotCodec _codec;

  const BullnymWalletMetadataRemoteRepository({
    required BullnymFacade bullnym,
    required WalletMetadataSnapshotCryptor snapshots,
    required NostrIdentityFacade identity,
    WalletMetadataSnapshotCodec codec = const WalletMetadataSnapshotCodec(),
    // Preserve public named parameters while keeping collaborators private.
    // ignore: prefer_initializing_formals
  }) : _bullnym = bullnym,
       // ignore: prefer_initializing_formals
       _snapshots = snapshots,
       // ignore: prefer_initializing_formals
       _identity = identity,
       // ignore: prefer_initializing_formals
       _codec = codec;

  @override
  @useResult
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial}) async {
    final fetched = await _bullnym.fetchBackup(
      signer: _signer(keyMaterial),
      stream: BullnymBackupStream.walletMetadata,
    );
    switch (fetched) {
      case Err(:final failure):
        return Err(_mapFailure(failure));
      case Ok(value: final remoteHead):
        final ciphertext = remoteHead.ciphertext;
        if (!remoteHead.found || ciphertext == null) {
          return Ok(
            WalletMetadataRemoteAbsent(
              generation: remoteHead.generation,
              etag: remoteHead.etag,
            ),
          );
        }
        final etag = remoteHead.etag;
        if (etag == null) {
          return const Err(WalletMetadataBackupEncodingFailure());
        }
        final decrypted = _snapshots.decrypt(
          keyMaterial: keyMaterial,
          ciphertext: ciphertext.value,
        );
        switch (decrypted) {
          case Err(
            failure: WalletMetadataBackupUpdateRequiredFailure(
              :final envelopeVersion,
            ),
          ):
            if (envelopeVersion == null) {
              return const Err(WalletMetadataBackupUpdateRequiredFailure());
            }
            return Ok(
              WalletMetadataRemoteUnsupported(
                generation: remoteHead.generation,
                etag: etag,
                envelopeVersion: envelopeVersion,
              ),
            );
          case Err(:final failure):
            return Err(failure);
          case Ok(value: final snapshot):
            return Ok(
              WalletMetadataRemotePresent(
                WalletMetadataRemoteHead(
                  generation: remoteHead.generation,
                  etag: etag,
                  snapshot: snapshot,
                  canonicalContentHash: _codec.contentHash(
                    records: snapshot.records,
                    sections: snapshot.sections,
                  ),
                ),
              ),
            );
        }
    }
  }

  @override
  @useResult
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required WalletMetadataEncryptedSnapshot snapshot,
    required int generation,
    required String? expectedEtag,
  }) async {
    if (generation <= 0) {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
    try {
      final stored = await _bullnym.storeBackup(
        signer: _signer(keyMaterial),
        stream: BullnymBackupStream.walletMetadata,
        currentHead: BullnymBackupHead.absent(
          generation: generation - 1,
          etag: expectedEtag,
        ),
        ciphertext: AuthenticatedBackupCiphertext(snapshot.ciphertext),
      );
      return switch (stored) {
        Err(:final failure) => Err(_mapFailure(failure)),
        Ok(:final value) => Ok(
          WalletMetadataRemoteStoreReceipt(
            generation: value.generation,
            etag: value.etag,
          ),
        ),
      };
    } on AuthenticatedBackupCipherException {
      return const Err(WalletMetadataBackupEncodingFailure());
    } on ArgumentError {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }

  @override
  @useResult
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  }) async {
    final fetched = await _bullnym.fetchBackup(
      signer: _signer(keyMaterial),
      stream: BullnymBackupStream.walletMetadata,
    );
    switch (fetched) {
      case Err(:final failure):
        return Err(_mapFailure(failure));
      case Ok(:final value):
        if (!value.found) {
          return const Ok(null);
        }
        final deleted = await _bullnym.deleteBackup(
          signer: _signer(keyMaterial),
          stream: BullnymBackupStream.walletMetadata,
          currentHead: value,
        );
        return switch (deleted) {
          Err(:final failure) => Err(_mapFailure(failure)),
          Ok() => const Ok(null),
        };
    }
  }

  BullnymAuthSigner _signer(WalletMetadataKeyMaterial keyMaterial) {
    return BullnymAuthSigner(
      npubHex: _identity.deriveWalletMetadataPublicKeyFromXprv(
        keyMaterial.xprvBase58,
      ),
      signHashHex: (hash) => _identity.signWalletMetadataHashFromXprv(
        xprvBase58: keyMaterial.xprvBase58,
        messageHashHex: hash,
      ),
    );
  }

  WalletMetadataBackupFailure _mapFailure(BullnymFailure failure) {
    return switch (failure.code) {
      'BackupHeadConflict' => const WalletMetadataBackupConflictFailure(),
      'BackupBlobTooLarge' => const WalletMetadataBackupResourceLimitFailure(),
      _ => WalletMetadataBackupRemoteFailure(
        failure.logMessage ?? failure.code,
      ),
    };
  }
}
