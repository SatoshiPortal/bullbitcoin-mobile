import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';

class KeychainManifestFile {
  static const currentVersion = 1;

  final int version;
  final String parentFingerprint;
  final int generatedAt;

  /// Data recency of the projected inventory: the latest `updatedAt` among
  /// included entries and materializations. An empty manifest carries no
  /// inventory, so it derives to `0` and sorts oldest in any cross-manifest
  /// recency ordering; it can never outrank a populated manifest.
  final int inventoryUpdatedAt;

  /// Integrity counts serialized into the v1 payload. They are derived from
  /// the actual entries on build; when a caller supplies them explicitly they
  /// must equal the actual counts.
  final int entryCount;
  final int materializationCount;
  final List<KeychainManifestFileEntry> entries;

  KeychainManifestFile({
    this.version = currentVersion,
    required String parentFingerprint,
    required this.generatedAt,
    int? entryCount,
    int? materializationCount,
    required List<KeychainManifestFileEntry> entries,
  }) : parentFingerprint = KeychainManifestFingerprint.normalize(
         parentFingerprint,
       ),
       inventoryUpdatedAt = _deriveInventoryUpdatedAt(entries),
       entryCount = entryCount ?? entries.length,
       materializationCount =
           materializationCount ?? _deriveMaterializationCount(entries),
       entries = List.unmodifiable(entries) {
    if (version != currentVersion) {
      throw KeychainManifestInvalidEntryException(
        'unsupported keychain manifest file version',
      );
    }
    if (generatedAt < 0) {
      throw KeychainManifestInvalidEntryException(
        'manifest file timestamps must be non-negative',
      );
    }
    if (this.entryCount != this.entries.length) {
      throw KeychainManifestInvalidEntryException(
        'manifest file entry count must match the actual entry count',
      );
    }
    if (this.materializationCount !=
        _deriveMaterializationCount(this.entries)) {
      throw KeychainManifestInvalidEntryException(
        'manifest file materialization count must match the actual '
        'materialization count',
      );
    }
    final entryIds = <String>{};
    final walletIds = <String>{};
    for (final entry in this.entries) {
      if (entry.parentFingerprint != this.parentFingerprint) {
        throw KeychainManifestInvalidEntryException(
          'manifest file entry parent fingerprint mismatch',
        );
      }
      if (!entryIds.add(entry.entryId)) {
        throw KeychainManifestInvalidEntryException(
          'manifest file entry ids must be unique',
        );
      }
      for (final materialization in entry.materializations) {
        if (!walletIds.add(materialization.walletId)) {
          throw KeychainManifestInvalidEntryException(
            'manifest file wallet ids must be unique',
          );
        }
      }
    }
  }

  static int _deriveMaterializationCount(
    List<KeychainManifestFileEntry> entries,
  ) {
    var count = 0;
    for (final entry in entries) {
      count += entry.materializations.length;
    }
    return count;
  }

  static int _deriveInventoryUpdatedAt(
    List<KeychainManifestFileEntry> entries,
  ) {
    var latest = 0;
    for (final entry in entries) {
      if (entry.updatedAt > latest) latest = entry.updatedAt;
      for (final materialization in entry.materializations) {
        if (materialization.updatedAt > latest) {
          latest = materialization.updatedAt;
        }
      }
    }
    return latest;
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
    // The path is serialized three times on the wire (path string,
    // application, index); the numeric fields must match the path segments.
    final segments = this.bip85DerivationPath.split('/');
    final firstSegment = int.parse(
      segments.first.substring(0, segments.first.length - 1),
    );
    final lastSegment = int.parse(
      segments.last.substring(0, segments.last.length - 1),
    );
    if (bip85Application != firstSegment) {
      throw KeychainManifestInvalidEntryException(
        'manifest file BIP85 application must match the first path segment',
      );
    }
    if (bip85Index != lastSegment) {
      throw KeychainManifestInvalidEntryException(
        'manifest file BIP85 index must match the last path segment',
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
