import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_entry.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_entry_repository.dart';
import 'package:drift/native.dart' show SqliteException;
import 'package:drift/drift.dart' show Value;

class DriftKeychainManifestEntryRepository
    implements KeychainManifestEntryRepository {
  final SqliteDatabase _database;

  DriftKeychainManifestEntryRepository({required this._database});

  Future<KeychainManifestWalletMaterializationRecord?>
  _fetchWalletMaterializationRecordByWalletId(String walletId) async {
    final bindingQuery = _database.select(
      _database.keychainManifestWalletBindings,
    )..where((table) => table.walletId.equals(walletId));
    final binding = await bindingQuery.getSingleOrNull();
    if (binding == null) return null;
    return _recordForBinding(binding);
  }

  @override
  Future<List<KeychainManifestWalletMaterializationRecord>>
  fetchWalletMaterializationRecordsByParentFingerprint(
    String parentFingerprint,
  ) async {
    final normalized = KeychainManifestFingerprint.normalize(parentFingerprint);
    return _database.transaction(() async {
      final entryQuery = _database.select(_database.keychainManifestEntries)
        ..where((table) => table.parentFingerprint.equals(normalized));
      final entries = await entryQuery.get();
      if (entries.isEmpty) return const [];

      final records = <KeychainManifestWalletMaterializationRecord>[];
      for (final entry in entries) {
        final bindingQuery = _database.select(
          _database.keychainManifestWalletBindings,
        )..where((table) => table.entryId.equals(entry.entryId));
        final bindings = await bindingQuery.get();
        for (final binding in bindings) {
          records.add(
            KeychainManifestWalletMaterializationRecord(
              entry: _rowToEntry(entry),
              walletMaterialization: _rowToWalletBinding(binding),
            ),
          );
        }
      }
      records.sort(_compareRecords);
      return records;
    });
  }

  int _compareRecords(
    KeychainManifestWalletMaterializationRecord left,
    KeychainManifestWalletMaterializationRecord right,
  ) {
    final pathCompare = left.entry.bip85DerivationPath.compareTo(
      right.entry.bip85DerivationPath,
    );
    if (pathCompare != 0) return pathCompare;
    final entryIdCompare = left.entry.entryId.compareTo(right.entry.entryId);
    if (entryIdCompare != 0) return entryIdCompare;
    final networkCompare = left.walletMaterialization.network.compareTo(
      right.walletMaterialization.network,
    );
    if (networkCompare != 0) return networkCompare;
    return left.walletId.compareTo(right.walletId);
  }

  @override
  Future<void> insertWalletMaterializationRecords(
    List<KeychainManifestWalletMaterializationRecord> records,
  ) async {
    if (records.isEmpty) return;
    try {
      await _database.transaction(() async {
        var changed = false;
        for (final record in records) {
          final existingByWallet =
              await _fetchWalletMaterializationRecordByWalletId(
                record.walletId,
              );
          if (existingByWallet != null) {
            if (existingByWallet.sameRecordAs(record)) continue;
            throw KeychainManifestEntryConflictException(
              'keychain manifest wallet materialization already exists',
            );
          }
          await _ensureEntry(record.entry);
          try {
            await _database
                .into(_database.keychainManifestWalletBindings)
                .insert(
                  KeychainManifestWalletBindingsCompanion.insert(
                    walletId: record.walletMaterialization.walletId,
                    entryId: record.walletMaterialization.entryId,
                    childSeedFingerprint:
                        record.walletMaterialization.childSeedFingerprint,
                    network: record.walletMaterialization.network,
                    scriptType: record.walletMaterialization.scriptType,
                    createdAt: record.walletMaterialization.createdAt,
                    updatedAt: record.walletMaterialization.updatedAt,
                  ),
                );
            changed = true;
          } catch (e) {
            if (!_isUniqueConstraintFailure(e)) rethrow;
            final insertedByWallet =
                await _fetchWalletMaterializationRecordByWalletId(
                  record.walletId,
                );
            if (insertedByWallet != null &&
                insertedByWallet.sameRecordAs(record)) {
              continue;
            }
            throw KeychainManifestEntryConflictException(
              'keychain manifest wallet materialization already exists',
              cause: e,
            );
          }
        }
        if (changed) await _markBackupDirty();
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

  Future<void> _markBackupDirty() async {
    final table = _database.keychainManifestBackupStates;
    final current = await (_database.select(
      table,
    )..where((row) => row.id.equals(1))).getSingleOrNull();
    if (current == null) {
      await _database
          .into(table)
          .insert(
            KeychainManifestBackupStatesCompanion.insert(
              id: const Value(1),
              dirty: const Value(true),
              dirtyRevision: const Value(1),
            ),
          );
      return;
    }
    await (_database.update(table)..where((row) => row.id.equals(1))).write(
      KeychainManifestBackupStatesCompanion(
        dirty: const Value(true),
        dirtyRevision: Value(current.dirtyRevision + 1),
      ),
    );
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

    try {
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
    } catch (e) {
      if (!_isUniqueConstraintFailure(e)) rethrow;
      final insertedQuery = _database.select(_database.keychainManifestEntries)
        ..where((table) => table.entryId.equals(entry.entryId));
      final inserted = await insertedQuery.getSingleOrNull();
      if (inserted != null && _rowToEntry(inserted).sameRecordAs(entry)) {
        return;
      }
      throw KeychainManifestDuplicateException(
        'keychain manifest entry identity already exists',
        cause: e,
      );
    }
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
