import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

final class KeychainManifestRepositoryImpl
    implements KeychainManifestRepository {
  final SqliteDatabase _database;
  final StreamController<void> _localChanges = StreamController.broadcast();

  KeychainManifestRepositoryImpl(this._database);

  @override
  Stream<void> watchLocalChanges() => _localChanges.stream;

  @override
  Future<Result<List<KeychainManifestEntry>, KeychainManifestFailure>> fetch(
    Fingerprint parentFingerprint,
  ) async {
    try {
      return Ok(
        await _database.transaction(() async {
          final query = _database.select(_database.keychainManifestEntries)
            ..where(
              (row) => row.parentFingerprint.equals(parentFingerprint.hex),
            );
          final rows = await query.get();
          final entries = <KeychainManifestEntry>[];
          for (final row in rows) {
            final wallets = await (_database.select(
              _database.keychainManifestWalletBindings,
            )..where((item) => item.entryId.equals(row.entryId))).get();
            final nostr =
                await (_database.select(_database.keychainManifestNostrKeys)
                      ..where((item) => item.entryId.equals(row.entryId)))
                    .getSingleOrNull();
            final items = <KeychainManifestMaterialization>[
              ...wallets.map(_walletEntity),
              if (nostr != null) _nostrEntity(nostr),
            ];
            if (items.isNotEmpty) entries.add(_entryEntity(row, items));
          }
          entries.sort(KeychainManifestEntry.compare);
          return entries;
        }),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to read keychain manifest',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> save(
    List<KeychainManifestEntry> entries, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) async {
    try {
      final changed = await _database.transaction(() async {
        var changed = false;
        for (final entry in entries) {
          changed = await _saveEntry(entry) || changed;
          for (final item in entry.materializations) {
            switch (item) {
              case KeychainManifestWallet():
                changed = await _saveWallet(item) || changed;
              case KeychainManifestNostrKey():
                changed = await _saveNostr(item) || changed;
            }
          }
        }
        return changed;
      });
      if (changed && origin == KeychainManifestWriteOrigin.local) {
        _localChanges.add(null);
      }
      return const Ok(null);
    } on _ManifestConflictException {
      return const Err(KeychainManifestConflictFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to write keychain manifest',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> updateNostrMetadata({
    required Fingerprint parentFingerprint,
    required String entryId,
    required String purpose,
    String? description,
    required int updatedAt,
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) async {
    final normalized = KeychainManifestNostrKey.tryNormalizeMetadata(
      purpose,
      description,
    );
    if (normalized == null || updatedAt < 0) {
      throw ArgumentError('Invalid Nostr metadata');
    }
    try {
      final outcome = await _database.transaction(() async {
        final entry = await (_database.select(
          _database.keychainManifestEntries,
        )..where((row) => row.entryId.equals(entryId))).getSingleOrNull();
        final key = await (_database.select(
          _database.keychainManifestNostrKeys,
        )..where((row) => row.entryId.equals(entryId))).getSingleOrNull();
        if (entry == null ||
            key == null ||
            entry.parentFingerprint != parentFingerprint.hex) {
          return (found: false, changed: false);
        }
        final metadataChanged =
            key.purpose != normalized.purpose ||
            key.description != normalized.description;
        if (!metadataChanged && updatedAt <= key.updatedAt) {
          return (found: true, changed: false);
        }
        final timestamp = metadataChanged && updatedAt <= key.updatedAt
            ? key.updatedAt + 1
            : updatedAt;
        await (_database.update(
          _database.keychainManifestNostrKeys,
        )..where((row) => row.entryId.equals(entryId))).write(
          KeychainManifestNostrKeysCompanion(
            purpose: Value(normalized.purpose),
            description: Value(normalized.description),
            updatedAt: Value(timestamp),
          ),
        );
        await (_database.update(
          _database.keychainManifestEntries,
        )..where((row) => row.entryId.equals(entryId))).write(
          KeychainManifestEntriesCompanion(updatedAt: Value(timestamp)),
        );
        return (found: true, changed: true);
      });
      if (outcome.changed && origin == KeychainManifestWriteOrigin.local) {
        _localChanges.add(null);
      }
      return outcome.found
          ? const Ok(null)
          : const Err(KeychainManifestConflictFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to update Nostr key metadata',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<void> close() => _localChanges.close();

  Future<bool> _saveEntry(KeychainManifestEntry entry) async {
    final query = _database.select(_database.keychainManifestEntries)
      ..where((row) => row.entryId.equals(entry.entryId));
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      if (existing.parentFingerprint == entry.parentFingerprint.hex &&
          existing.bip85DerivationPath == entry.bip85DerivationPath) {
        return false;
      }
      throw const _ManifestConflictException();
    }
    await _database
        .into(_database.keychainManifestEntries)
        .insert(
          KeychainManifestEntriesCompanion.insert(
            entryId: entry.entryId,
            parentFingerprint: entry.parentFingerprint.hex,
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
    return true;
  }

  Future<bool> _saveWallet(KeychainManifestWallet wallet) async {
    final query = _database.select(_database.keychainManifestWalletBindings)
      ..where((row) => row.walletId.equals(wallet.walletId));
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      if (existing.entryId == wallet.entryId &&
          existing.childSeedFingerprint == wallet.childSeedFingerprint.hex &&
          existing.network == wallet.network.name &&
          existing.scriptType == wallet.scriptType.name) {
        return false;
      }
      throw const _ManifestConflictException();
    }
    await _database
        .into(_database.keychainManifestWalletBindings)
        .insert(
          KeychainManifestWalletBindingsCompanion.insert(
            walletId: wallet.walletId,
            entryId: wallet.entryId,
            childSeedFingerprint: wallet.childSeedFingerprint.hex,
            network: wallet.network.name,
            scriptType: wallet.scriptType.name,
            createdAt: wallet.createdAt,
            updatedAt: wallet.updatedAt,
          ),
        );
    return true;
  }

  Future<bool> _saveNostr(KeychainManifestNostrKey key) async {
    final query = _database.select(_database.keychainManifestNostrKeys)
      ..where((row) => row.entryId.equals(key.entryId));
    final existing = await query.getSingleOrNull();
    if (existing != null) {
      if (existing.publicKeyHex == key.publicKeyHex &&
          existing.keyKind == key.keyKind.name &&
          existing.purpose == key.purpose &&
          existing.description == key.description &&
          existing.updatedAt == key.updatedAt) {
        return false;
      }
      throw const _ManifestConflictException();
    }
    await _database
        .into(_database.keychainManifestNostrKeys)
        .insert(
          KeychainManifestNostrKeysCompanion.insert(
            entryId: key.entryId,
            publicKeyHex: key.publicKeyHex,
            keyKind: key.keyKind.name,
            purpose: key.purpose,
            description: Value(key.description),
            createdAt: key.createdAt,
            updatedAt: key.updatedAt,
          ),
        );
    return true;
  }

  KeychainManifestEntry _entryEntity(
    KeychainManifestEntryRow row,
    List<KeychainManifestMaterialization> items,
  ) => KeychainManifestEntry(
    parentFingerprint: Fingerprint(row.parentFingerprint),
    bip85DerivationPath: row.bip85DerivationPath,
    reservationId: row.reservationId,
    entryType: row.entryType,
    ownerFeature: row.ownerFeature,
    bip85Application: row.bip85Application,
    bip85Index: row.bip85Index,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    materializations: items,
  );

  KeychainManifestWallet _walletEntity(KeychainManifestWalletBindingRow row) =>
      KeychainManifestWallet(
        walletId: row.walletId,
        entryId: row.entryId,
        childSeedFingerprint: Fingerprint(row.childSeedFingerprint),
        network: Network.fromName(row.network),
        scriptType: ScriptType.fromName(row.scriptType),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  KeychainManifestNostrKey _nostrEntity(KeychainManifestNostrKeyRow row) =>
      KeychainManifestNostrKey(
        entryId: row.entryId,
        publicKeyHex: row.publicKeyHex,
        keyKind: KeychainManifestNostrKeyKind.values.byName(row.keyKind),
        purpose: row.purpose,
        description: row.description,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

final class _ManifestConflictException implements Exception {
  const _ManifestConflictException();
}
