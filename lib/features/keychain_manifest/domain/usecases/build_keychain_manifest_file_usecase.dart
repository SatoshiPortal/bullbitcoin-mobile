import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_file.dart';

class BuildKeychainManifestFileUsecase {
  final KeychainManifestEntryRepository repository;

  const BuildKeychainManifestFileUsecase({required this.repository});

  Future<KeychainManifestFile> execute(
    String parentFingerprint, {
    DateTime? now,
  }) async {
    final generatedAt =
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch ~/ 1000;
    final normalizedParentFingerprint = KeychainManifestFingerprint.normalize(
      parentFingerprint,
    );
    final records = await repository
        .fetchWalletMaterializationRecordsByParentFingerprint(
          normalizedParentFingerprint,
        );
    final entries = _entriesFromRecords(records);
    return KeychainManifestFile(
      parentFingerprint: normalizedParentFingerprint,
      generatedAt: generatedAt,
      inventoryUpdatedAt: _inventoryUpdatedAt(entries, generatedAt),
      entries: entries,
    );
  }

  List<KeychainManifestFileEntry> _entriesFromRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) {
    final grouped =
        <String, List<KeychainManifestWalletMaterializationRecord>>{};
    for (final record in records) {
      grouped.putIfAbsent(record.entry.entryId, () => []).add(record);
    }
    final entries = grouped.values
        .map((recordsForEntry) {
          recordsForEntry.sort(_compareRecordsForMaterializationOrder);
          final materializations = recordsForEntry
              .map(KeychainManifestFileWalletMaterialization.fromRecord)
              .toList(growable: false);
          return KeychainManifestFileEntry.fromRecord(
            recordsForEntry.first,
            materializations: materializations,
          );
        })
        .toList(growable: false);
    entries.sort((left, right) {
      final pathCompare = left.bip85DerivationPath.compareTo(
        right.bip85DerivationPath,
      );
      if (pathCompare != 0) return pathCompare;
      return left.entryId.compareTo(right.entryId);
    });
    return entries;
  }

  int _compareRecordsForMaterializationOrder(
    KeychainManifestWalletMaterializationRecord left,
    KeychainManifestWalletMaterializationRecord right,
  ) {
    final networkCompare = left.walletMaterialization.network.compareTo(
      right.walletMaterialization.network,
    );
    if (networkCompare != 0) return networkCompare;
    return left.walletId.compareTo(right.walletId);
  }

  int _inventoryUpdatedAt(
    List<KeychainManifestFileEntry> entries,
    int generatedAt,
  ) {
    if (entries.isEmpty) return generatedAt;
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
