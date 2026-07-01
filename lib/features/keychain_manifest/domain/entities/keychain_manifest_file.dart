import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';

class KeychainManifestFile {
  static const currentVersion = 1;

  final int version;
  final String parentFingerprint;
  final int generatedAt;
  final int inventoryUpdatedAt;
  final List<KeychainManifestFileEntry> entries;

  KeychainManifestFile({
    this.version = currentVersion,
    required String parentFingerprint,
    required this.generatedAt,
    required this.inventoryUpdatedAt,
    required List<KeychainManifestFileEntry> entries,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       entries = List.unmodifiable(entries) {
    if (version != currentVersion) {
      throw KeychainManifestInvalidEntryException(
        'unsupported keychain manifest file version',
      );
    }
    if (generatedAt < 0 || inventoryUpdatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'manifest file timestamps must be non-negative',
      );
    }
    for (final entry in this.entries) {
      if (entry.parentFingerprint != this.parentFingerprint) {
        throw KeychainManifestInvalidEntryException(
          'manifest file entry parent fingerprint mismatch',
        );
      }
    }
  }
}

class KeychainManifestFileEntry {
  final String entryId;
  final String parentFingerprint;
  final String bip85DerivationPath;
  final String reservationId;
  final String entryType;
  final String ownerFeature;
  final int bip85Application;
  final int bip85Index;
  final int createdAt;
  final int updatedAt;
  final List<KeychainManifestFileWalletMaterialization> materializations;

  KeychainManifestFileEntry({
    String? entryId,
    required String parentFingerprint,
    required String bip85DerivationPath,
    required this.reservationId,
    required this.entryType,
    required this.ownerFeature,
    required this.bip85Application,
    required this.bip85Index,
    required this.createdAt,
    required this.updatedAt,
    required List<KeychainManifestFileWalletMaterialization> materializations,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       bip85DerivationPath = KeychainManifestBip85Path.normalize(
         bip85DerivationPath,
       ),
       entryId =
           entryId ??
           KeychainManifestEntryId.fromIdentity(
             parentFingerprint: parentFingerprint,
             bip85DerivationPath: bip85DerivationPath,
           ),
       materializations = List.unmodifiable(materializations) {
    final expectedEntryId = KeychainManifestEntryId.fromIdentity(
      parentFingerprint: this.parentFingerprint,
      bip85DerivationPath: this.bip85DerivationPath,
    );
    if (this.entryId != expectedEntryId) {
      throw KeychainManifestInvalidEntryException(
        'manifest file entry id must match entry identity',
      );
    }
    if (reservationId.trim().isEmpty ||
        entryType.trim().isEmpty ||
        ownerFeature.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'manifest file entry metadata is required',
      );
    }
    if (bip85Application < 0 || bip85Index < 0) {
      throw KeychainManifestInvalidEntryException(
        'manifest file BIP85 metadata must be non-negative',
      );
    }
    if (createdAt < 0 || updatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'manifest file entry timestamps must be non-negative',
      );
    }
    if (this.materializations.isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'manifest file entry requires at least one materialization',
      );
    }
    for (final materialization in this.materializations) {
      if (materialization.entryId != this.entryId) {
        throw KeychainManifestInvalidEntryException(
          'manifest file materialization entry id mismatch',
        );
      }
    }
  }

  factory KeychainManifestFileEntry.fromRecord(
    KeychainManifestWalletMaterializationRecord record, {
    required List<KeychainManifestFileWalletMaterialization> materializations,
  }) {
    final entry = record.entry;
    return KeychainManifestFileEntry(
      entryId: entry.entryId,
      parentFingerprint: entry.parentFingerprint,
      bip85DerivationPath: entry.bip85DerivationPath,
      reservationId: entry.reservationId,
      entryType: entry.entryType,
      ownerFeature: entry.ownerFeature,
      bip85Application: entry.bip85Application,
      bip85Index: entry.bip85Index,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
      materializations: materializations,
    );
  }
}

class KeychainManifestFileWalletMaterialization {
  static const type = 'wallet';

  final String walletId;
  final String entryId;
  final String childSeedFingerprint;
  final String network;
  final String scriptType;
  final int createdAt;
  final int updatedAt;

  KeychainManifestFileWalletMaterialization({
    required this.walletId,
    required this.entryId,
    required String childSeedFingerprint,
    required this.network,
    required this.scriptType,
    required this.createdAt,
    required this.updatedAt,
  }) : childSeedFingerprint = KeychainManifestFingerprint.normalize(
         childSeedFingerprint,
       ) {
    if (walletId.trim().isEmpty ||
        entryId.trim().isEmpty ||
        network.trim().isEmpty ||
        scriptType.trim().isEmpty) {
      throw KeychainManifestInvalidEntryException(
        'manifest file wallet materialization metadata is required',
      );
    }
    if (createdAt < 0 || updatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'manifest file materialization timestamps must be non-negative',
      );
    }
  }

  factory KeychainManifestFileWalletMaterialization.fromRecord(
    KeychainManifestWalletMaterializationRecord record,
  ) {
    final materialization = record.walletMaterialization;
    return KeychainManifestFileWalletMaterialization(
      walletId: materialization.walletId,
      entryId: materialization.entryId,
      childSeedFingerprint: materialization.childSeedFingerprint,
      network: materialization.network,
      scriptType: materialization.scriptType,
      createdAt: materialization.createdAt,
      updatedAt: materialization.updatedAt,
    );
  }
}
