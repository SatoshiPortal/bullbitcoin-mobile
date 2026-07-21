import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_snapshot.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_encryption_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_remote_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/build_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/derive_keychain_manifest_encryption_key_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/parse_keychain_manifest_file_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

class SyncKeychainManifestBackupUsecase {
  final BuildKeychainManifestFileUsecase buildManifestFile;
  final DeriveKeychainManifestEncryptionKeyUsecase deriveEncryptionKey;
  final KeychainManifestEncryptionRepository encryption;
  final KeychainManifestRemoteRepository remote;
  final ParseKeychainManifestFileUsecase parseManifest;
  final NostrIdentityFacade identity;

  const SyncKeychainManifestBackupUsecase({
    required this.buildManifestFile,
    required this.encryption,
    required this.remote,
    required this.parseManifest,
    required this.identity,
    this.deriveEncryptionKey =
        const DeriveKeychainManifestEncryptionKeyUsecase(),
  });

  Future<KeychainManifestBackupSyncResult> execute({
    required String parentFingerprint,
    required String xprvBase58,
    DateTime? now,
  }) async {
    final local = await buildManifestFile.execute(parentFingerprint, now: now);
    if (local.entries.isEmpty) throw KeychainManifestEmptyInventoryException();
    final key = deriveEncryptionKey.execute(
      xprvBase58: xprvBase58,
      expectedParentFingerprint: parentFingerprint,
    );
    final signer = _signer(xprvBase58);

    for (var attempt = 0; attempt < 2; attempt++) {
      final current = await remote.fetch(signer);
      final remoteSnapshot = current.ciphertext == null
          ? null
          : encryption.decryptSnapshot(
              ciphertext: current.ciphertext!,
              key: key,
            );
      final remoteFile = remoteSnapshot?.manifestFile;
      if (remoteFile != null) {
        parseManifest.executeFile(
          remoteFile,
          expectedParentFingerprint: parentFingerprint,
          allowEmpty: true,
        );
      }
      final merged = _merge(local, remoteFile, now: now);
      final snapshot = KeychainManifestBackupSnapshot(manifestFile: merged);
      final contentHash = encryption.contentHash(snapshot);
      if (remoteSnapshot != null &&
          contentHash == encryption.contentHash(remoteSnapshot)) {
        return KeychainManifestBackupSyncResult(
          checkpoint: KeychainManifestRemoteCheckpoint(
            generation: current.generation,
            etag: current.etag!,
          ),
          contentHash: contentHash,
        );
      }
      final ciphertext = encryption.encryptSnapshot(
        snapshot: snapshot,
        key: key,
      );
      try {
        final checkpoint = await remote.store(
          signer: signer,
          current: current,
          ciphertext: ciphertext,
        );
        return KeychainManifestBackupSyncResult(
          checkpoint: checkpoint,
          contentHash: contentHash,
        );
      } on KeychainManifestRemoteException catch (error) {
        if (error.reason != KeychainManifestRemoteFailureReason.headConflict ||
            attempt == 1) {
          rethrow;
        }
      }
    }
    throw KeychainManifestGenericException();
  }

  KeychainManifestBackupSigner _signer(String xprvBase58) {
    return KeychainManifestBackupSigner(
      publicKeyHex: identity.deriveWalletManifestPublicKeyFromXprv(xprvBase58),
      signHashHex: (hash) => identity.signWalletManifestHashFromXprv(
        xprvBase58: xprvBase58,
        messageHashHex: hash,
      ),
    );
  }

  KeychainManifestFile _merge(
    KeychainManifestFile local,
    KeychainManifestFile? remoteFile, {
    DateTime? now,
  }) {
    if (remoteFile == null) return local;
    if (remoteFile.parentFingerprint != local.parentFingerprint) {
      throw KeychainManifestEntryConflictException(
        'remote manifest belongs to a different parent fingerprint',
      );
    }
    final entries = <String, KeychainManifestFileEntry>{
      for (final entry in remoteFile.entries) entry.entryId: entry,
    };
    for (final entry in local.entries) {
      final existing = entries[entry.entryId];
      if (existing == null) {
        entries[entry.entryId] = entry;
      } else {
        entries[entry.entryId] = _mergeEntry(existing, entry);
      }
    }
    if (_sameEntries(remoteFile.entries, entries.values)) return remoteFile;
    final sortedEntries = entries.values.toList(growable: false)
      ..sort((left, right) {
        final path = left.bip85DerivationPath.compareTo(
          right.bip85DerivationPath,
        );
        return path != 0 ? path : left.entryId.compareTo(right.entryId);
      });
    return KeychainManifestFile(
      parentFingerprint: local.parentFingerprint,
      generatedAt:
          (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000,
      entries: sortedEntries,
    );
  }

  KeychainManifestFileEntry _mergeEntry(
    KeychainManifestFileEntry first,
    KeychainManifestFileEntry second,
  ) {
    if (first.bip85DerivationPath != second.bip85DerivationPath ||
        first.reservationId != second.reservationId ||
        first.entryType != second.entryType ||
        first.ownerFeature != second.ownerFeature ||
        first.bip85Application != second.bip85Application ||
        first.bip85Index != second.bip85Index) {
      throw KeychainManifestEntryConflictException(
        'remote manifest entry conflicts with local inventory',
      );
    }
    final materializations =
        <String, KeychainManifestFileWalletMaterialization>{
          for (final item in first.materializations) item.walletId: item,
        };
    for (final item in second.materializations) {
      final existing = materializations[item.walletId];
      if (existing != null &&
          (existing.entryId != item.entryId ||
              existing.childSeedFingerprint != item.childSeedFingerprint ||
              existing.network != item.network ||
              existing.scriptType != item.scriptType)) {
        throw KeychainManifestEntryConflictException(
          'remote wallet materialization conflicts with local inventory',
        );
      }
      materializations[item.walletId] = item;
    }
    final sortedMaterializations =
        materializations.values.toList(growable: false)..sort((left, right) {
          final network = left.network.compareTo(right.network);
          return network != 0
              ? network
              : left.walletId.compareTo(right.walletId);
        });
    return KeychainManifestFileEntry(
      parentFingerprint: first.parentFingerprint,
      bip85DerivationPath: first.bip85DerivationPath,
      reservationId: first.reservationId,
      entryType: first.entryType,
      ownerFeature: first.ownerFeature,
      bip85Application: first.bip85Application,
      bip85Index: first.bip85Index,
      createdAt: first.createdAt < second.createdAt
          ? first.createdAt
          : second.createdAt,
      updatedAt: first.updatedAt > second.updatedAt
          ? first.updatedAt
          : second.updatedAt,
      materializations: sortedMaterializations,
    );
  }

  bool _sameEntries(
    List<KeychainManifestFileEntry> current,
    Iterable<KeychainManifestFileEntry> merged,
  ) {
    final mergedById = {for (final entry in merged) entry.entryId: entry};
    if (current.length != mergedById.length) return false;
    return current.every(
      (entry) => _sameEntry(entry, mergedById[entry.entryId]),
    );
  }

  bool _sameEntry(
    KeychainManifestFileEntry current,
    KeychainManifestFileEntry? merged,
  ) {
    if (merged == null ||
        current.entryId != merged.entryId ||
        current.parentFingerprint != merged.parentFingerprint ||
        current.bip85DerivationPath != merged.bip85DerivationPath ||
        current.reservationId != merged.reservationId ||
        current.entryType != merged.entryType ||
        current.ownerFeature != merged.ownerFeature ||
        current.bip85Application != merged.bip85Application ||
        current.bip85Index != merged.bip85Index ||
        current.createdAt != merged.createdAt ||
        current.updatedAt != merged.updatedAt ||
        current.materializations.length != merged.materializations.length) {
      return false;
    }
    final mergedByWallet = {
      for (final item in merged.materializations) item.walletId: item,
    };
    return current.materializations.every((item) {
      final other = mergedByWallet[item.walletId];
      return other != null &&
          item.entryId == other.entryId &&
          item.childSeedFingerprint == other.childSeedFingerprint &&
          item.network == other.network &&
          item.scriptType == other.scriptType &&
          item.createdAt == other.createdAt &&
          item.updatedAt == other.updatedAt;
    });
  }
}
