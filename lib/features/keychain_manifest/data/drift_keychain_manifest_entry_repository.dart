import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:drift/native.dart' show SqliteException;

class DriftKeychainManifestEntryRepository
    implements KeychainManifestEntryRepository {
  final SqliteDatabase _database;

  DriftKeychainManifestEntryRepository({required this._database});

  @override
  Future<KeychainManifestWalletMaterializationRecord?>
  fetchWalletMaterializationRecordByWalletId(String walletId) async {
    final bindingQuery = _database.select(
      _database.keychainManifestWalletBindings,
    )..where((table) => table.walletId.equals(walletId));
    final binding = await bindingQuery.getSingleOrNull();
    if (binding == null) return null;
    return _recordForBinding(binding);
  }

  @override
  Future<void> insertWalletMaterializationRecord(
    KeychainManifestWalletMaterializationRecord record,
  ) async {
    try {
      await _database.transaction(() async {
        await _ensureEntry(record.entry);
        await _database
            .into(_database.keychainManifestWalletBindings)
            .insert(
              KeychainManifestWalletBindingsCompanion.insert(
                walletId: record.walletMaterialization.walletId,
                entryId: record.walletMaterialization.entryId,
                childSeedFingerprint:
                    record.walletMaterialization.childSeedFingerprint,
                network: record.walletMaterialization.network,
                walletPurpose: record.walletMaterialization.walletPurpose,
                scriptType: record.walletMaterialization.scriptType,
                createdAt: record.walletMaterialization.createdAt,
                updatedAt: record.walletMaterialization.updatedAt,
              ),
            );
      });
    } catch (e) {
      if (_isUniqueConstraintFailure(e)) {
        throw KeychainManifestDuplicateException(
          'keychain manifest wallet materialization already exists',
          cause: e,
        );
      }
      rethrow;
    }
  }

  Future<void> _ensureEntry(KeychainManifestEntry entry) async {
    final existingQuery = _database.select(_database.keychainManifestEntries)
      ..where((table) => table.entryId.equals(entry.entryId));
    final existing = await existingQuery.getSingleOrNull();
    if (existing != null) {
      if (_rowToEntry(existing).sameRecordAs(entry)) return;
      throw KeychainManifestDuplicateException(
        'keychain manifest entry identity already exists',
      );
    }

    await _database
        .into(_database.keychainManifestEntries)
        .insert(
          KeychainManifestEntriesCompanion.insert(
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
          ),
        );
  }

  Future<KeychainManifestWalletMaterializationRecord> _recordForBinding(
    KeychainManifestWalletBindingRow binding,
  ) async {
    final entryQuery = _database.select(_database.keychainManifestEntries)
      ..where((table) => table.entryId.equals(binding.entryId));
    final entry = await entryQuery.getSingle();
    return KeychainManifestWalletMaterializationRecord(
      entry: _rowToEntry(entry),
      walletMaterialization: _rowToWalletBinding(binding),
    );
  }

  KeychainManifestEntry _rowToEntry(KeychainManifestEntryRow row) {
    return KeychainManifestEntry(
      entryId: row.entryId,
      parentFingerprint: row.parentFingerprint,
      bip85DerivationPath: row.bip85DerivationPath,
      reservationId: row.reservationId,
      entryType: row.entryType,
      ownerFeature: row.ownerFeature,
      bip85Application: row.bip85Application,
      bip85Index: row.bip85Index,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  KeychainManifestWalletMaterialization _rowToWalletBinding(
    KeychainManifestWalletBindingRow row,
  ) {
    return KeychainManifestWalletMaterialization(
      walletId: row.walletId,
      entryId: row.entryId,
      childSeedFingerprint: row.childSeedFingerprint,
      network: row.network,
      walletPurpose: row.walletPurpose,
      scriptType: row.scriptType,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  bool _isUniqueConstraintFailure(Object error) {
    if (error is SqliteException) {
      return error.extendedResultCode == 2067 ||
          error.extendedResultCode == 1555;
    }
    return false;
  }
}
