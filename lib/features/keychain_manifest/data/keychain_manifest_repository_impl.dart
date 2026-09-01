import 'dart:async';

import 'package:bb_mobile/core/storage/backup_revision_recorder.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_requests.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_repository.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart' show Err, Fingerprint, Ok, Result;

final class KeychainManifestRepositoryImpl
    implements KeychainManifestRepository {
  final SqliteDatabase _database;

  /// Bull backup's dirty signal, raised inside the same transaction as the
  /// write that earned it (decision 7). Forgetting a wallet depends on it: a
  /// signal lost to a crash would leave the forgotten wallet in the next
  /// published snapshot.
  final BackupRevisionRecorder _backupRevisions;
  final StreamController<void> _localChanges = StreamController.broadcast();

  KeychainManifestRepositoryImpl(
    this._database, {
    this._backupRevisions = const NoBackupRevisionRecorder(),
  });

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
            final wallets = await _walletRowsOf(row.entryId);
            final nostr = await _nostrRow(row.entryId);
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
  Future<Result<void, KeychainManifestFailure>> replaceSeedWalletInventory(
    Fingerprint parentFingerprint,
    List<KeychainManifestEntry> entries,
  ) async {
    if (entries.any(
      (entry) =>
          entry.parentFingerprint != parentFingerprint ||
          entry.derivationKind != KeychainManifestDerivationKind.bip32,
    )) {
      return const Err(KeychainManifestConflictFailure());
    }
    try {
      final current = await fetch(parentFingerprint);
      final List<KeychainManifestEntry> existing;
      switch (current) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          existing = value
              .where(
                (entry) =>
                    entry.derivationKind ==
                    KeychainManifestDerivationKind.bip32,
              )
              .toList(growable: false);
      }
      final replacementWalletIds = {
        for (final entry in entries) _walletOf(entry).walletId,
      };
      // A record the user made rather than the app derived survives a
      // re-derivation it is missing from; nothing else can bring it back.
      final effective = [
        ...entries,
        for (final entry in existing)
          if (_isUserOwned(_walletOf(entry)) &&
              !replacementWalletIds.contains(_walletOf(entry).walletId))
            entry,
      ];
      if (_sameWalletInventory(existing, effective)) return const Ok(null);

      await _database.transaction(() async {
        final query = _database.select(_database.keychainManifestEntries)
          ..where(
            (row) =>
                row.parentFingerprint.equals(parentFingerprint.hex) &
                row.derivationKind.equals(
                  KeychainManifestDerivationKind.bip32.name,
                ),
          );
        final entryIds = (await query.get())
            .map((entry) => entry.entryId)
            .toList(growable: false);
        if (entryIds.isNotEmpty) {
          await (_database.delete(
            _database.keychainManifestWalletBindings,
          )..where((row) => row.entryId.isIn(entryIds))).go();
          await (_database.delete(
            _database.keychainManifestEntries,
          )..where((row) => row.entryId.isIn(entryIds))).go();
        }
        for (final entry in effective) {
          await _insertEntry(entry);
          await _insertWallet(_walletOf(entry));
        }
        await _backupRevisions.recordCommittedMutation();
      });
      _localChanges.add(null);
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to replace wallet recovery inventory',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> upsertPassphraseWallet(
    KeychainManifestEntry record,
  ) async {
    final wallet = _tryWalletOf(record);
    if (wallet == null) return const Err(KeychainManifestConflictFailure());
    try {
      final changed = await _database.transaction(() async {
        final storedEntry = await _entryRow(record.entryId);
        if (storedEntry == null) {
          // The wallet id may still be bound under another entry, which would
          // be a different wallet wearing the same identity.
          if (await _walletRow(wallet.walletId) != null) {
            throw const _ManifestConflictException();
          }
          await _insertEntry(record);
          await _insertWallet(wallet);
          await _backupRevisions.recordCommittedMutation();
          return true;
        }
        final stored = await _matchingWalletRow(record, wallet, storedEntry);
        if (stored == null) throw const _ManifestConflictException();
        if (storedEntry.description == record.description &&
            stored.label == wallet.label) {
          return false;
        }
        // A local upsert is the newest statement about this wallet, so it takes
        // the later of its own timestamp and one past the stored revision.
        await _writeWalletMetadata(
          entryId: record.entryId,
          walletId: wallet.walletId,
          description: record.description,
          label: wallet.label,
          updatedAt: record.updatedAt > storedEntry.updatedAt
              ? record.updatedAt
              : storedEntry.updatedAt + 1,
        );
        await _backupRevisions.recordCommittedMutation();
        return true;
      });
      if (changed) _localChanges.add(null);
      return const Ok(null);
    } on _ManifestConflictException {
      return const Err(KeychainManifestConflictFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to record wallet recovery record',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> updatePassphraseLabelHint({
    required Fingerprint parentFingerprint,
    required String walletId,
    KeychainManifestEdit<String?>? label,
    KeychainManifestEdit<String?>? hint,
    required int updatedAt,
  }) async {
    if (label == null && hint == null) return const Ok(null);
    final newLabel = label == null ? null : _text(label.value);
    final newHint = hint == null ? null : _text(hint.value);
    if ((newHint?.length ?? 0) > KeychainManifestEntry.maxDescriptionLength ||
        (newLabel?.length ?? 0) > KeychainManifestWallet.maxLabelLength ||
        _hasControlCharacter(newLabel) ||
        _hasControlCharacter(newHint) ||
        !isValidKeychainManifestTimestamp(updatedAt)) {
      return const Err(KeychainManifestConflictFailure());
    }
    try {
      final outcome = await _database.transaction(() async {
        final binding = await _walletRow(walletId);
        if (binding == null) return (accepted: false, changed: false);
        final entry = await _entryRow(binding.entryId);
        if (entry == null || entry.parentFingerprint != parentFingerprint.hex) {
          return (accepted: false, changed: false);
        }
        final description = hint == null ? entry.description : newHint;
        final display = label == null ? binding.label : newLabel;
        if (description == entry.description && display == binding.label) {
          return (accepted: true, changed: false);
        }
        if (updatedAt <= _revisionOf(entry, binding)) {
          return (accepted: false, changed: false);
        }
        await _writeWalletMetadata(
          entryId: entry.entryId,
          walletId: walletId,
          description: description,
          label: display,
          updatedAt: updatedAt,
        );
        await _backupRevisions.recordCommittedMutation();
        return (accepted: true, changed: true);
      });
      if (outcome.changed) _localChanges.add(null);
      return outcome.accepted
          ? const Ok(null)
          : const Err(KeychainManifestConflictFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to update wallet recovery metadata',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> removePassphraseWallet({
    required Fingerprint parentFingerprint,
    required String walletId,
  }) async {
    try {
      final found = await _database.transaction(() async {
        final wallet = await _walletRow(walletId);
        if (wallet == null) return false;
        final entry = await _entryRow(wallet.entryId);
        if (entry == null || entry.parentFingerprint != parentFingerprint.hex) {
          return false;
        }
        await (_database.delete(
          _database.keychainManifestWalletBindings,
        )..where((row) => row.walletId.equals(walletId))).go();
        await (_database.delete(
          _database.keychainManifestEntries,
        )..where((row) => row.entryId.equals(entry.entryId))).go();
        await _backupRevisions.recordCommittedMutation();
        return true;
      });
      if (!found) return const Err(KeychainManifestConflictFailure());
      _localChanges.add(null);
      return const Ok(null);
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to forget wallet recovery metadata',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<KeychainManifestRestoreReport, KeychainManifestFailure>>
  restoreSnapshot(
    KeychainManifest manifest, {
    KeychainManifestRestorePolicy policy =
        KeychainManifestRestorePolicy.keepNewest,
  }) async {
    try {
      return Ok(
        await _database.transaction(() async {
          var applied = 0;
          var unchanged = 0;
          final conflicts = <String>[];
          for (final record in manifest.entries) {
            final wallet = _tryWalletOf(record);
            switch (wallet == null
                ? _Restored.conflict
                : await _restoreWallet(record, wallet)) {
              case _Restored.applied:
                applied++;
              case _Restored.unchanged:
                unchanged++;
              case _Restored.conflict:
                conflicts.add(record.entryId);
            }
          }
          return KeychainManifestRestoreReport(
            applied: applied,
            unchanged: unchanged,
            conflicts: conflicts,
          );
        }),
      );
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to restore keychain manifest',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(KeychainManifestStorageFailure());
    }
  }

  @override
  Future<Result<void, KeychainManifestFailure>> insertNostrKey(
    KeychainManifestEntry record, {
    KeychainManifestWriteOrigin origin = KeychainManifestWriteOrigin.local,
  }) async {
    final key = record.materializations.length == 1
        ? record.materializations.single
        : null;
    if (key is! KeychainManifestNostrKey) {
      return const Err(KeychainManifestConflictFailure());
    }
    try {
      final changed = await _database.transaction(() async {
        final storedEntry = await _entryRow(record.entryId);
        final storedKey = await _nostrRow(record.entryId);
        if (storedEntry != null || storedKey != null) {
          if (storedEntry == null ||
              storedKey == null ||
              !_sameEntryShape(storedEntry, record) ||
              storedEntry.description != record.description ||
              storedKey.publicKeyHex != key.publicKeyHex ||
              storedKey.keyKind != key.keyKind.name ||
              storedKey.purpose != key.purpose ||
              storedKey.updatedAt != key.updatedAt) {
            throw const _ManifestConflictException();
          }
          return false;
        }
        await _insertEntry(record);
        await _database
            .into(_database.keychainManifestNostrKeys)
            .insert(
              KeychainManifestNostrKeysCompanion.insert(
                entryId: key.entryId,
                publicKeyHex: key.publicKeyHex,
                keyKind: key.keyKind.name,
                purpose: key.purpose,
                createdAt: key.createdAt,
                updatedAt: key.updatedAt,
              ),
            );
        if (origin == KeychainManifestWriteOrigin.local) {
          await _backupRevisions.recordCommittedMutation();
        }
        return true;
      });
      if (changed && origin == KeychainManifestWriteOrigin.local) {
        _localChanges.add(null);
      }
      return const Ok(null);
    } on _ManifestConflictException {
      return const Err(KeychainManifestConflictFailure());
    } on Exception catch (error, trace) {
      log.warning(
        'Failed to record Nostr key materialization',
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
    final normalizedPurpose = KeychainManifestNostrKey.tryNormalizePurpose(
      purpose,
    );
    final normalizedDescription = _text(description);
    if (normalizedPurpose == null ||
        (normalizedDescription?.length ?? 0) >
            KeychainManifestEntry.maxDescriptionLength ||
        _hasControlCharacter(normalizedDescription) ||
        updatedAt < 0) {
      throw ArgumentError('Invalid Nostr metadata');
    }
    try {
      final outcome = await _database.transaction(() async {
        final entry = await _entryRow(entryId);
        final key = await _nostrRow(entryId);
        if (entry == null ||
            key == null ||
            entry.parentFingerprint != parentFingerprint.hex) {
          return (found: false, changed: false);
        }
        final metadataChanged =
            key.purpose != normalizedPurpose ||
            entry.description != normalizedDescription;
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
            purpose: Value(normalizedPurpose),
            updatedAt: Value(timestamp),
          ),
        );
        await (_database.update(
          _database.keychainManifestEntries,
        )..where((row) => row.entryId.equals(entryId))).write(
          KeychainManifestEntriesCompanion(
            description: Value(normalizedDescription),
            updatedAt: Value(timestamp),
          ),
        );
        if (origin == KeychainManifestWriteOrigin.local) {
          await _backupRevisions.recordCommittedMutation();
        }
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

  /// One restored wallet record under
  /// [KeychainManifestRestorePolicy.keepNewest].
  Future<_Restored> _restoreWallet(
    KeychainManifestEntry record,
    KeychainManifestWallet wallet,
  ) async {
    final storedEntry = await _entryRow(record.entryId);
    if (storedEntry == null) {
      if (await _walletRow(wallet.walletId) != null) return _Restored.conflict;
      await _insertEntry(record);
      await _insertWallet(wallet);
      return _Restored.applied;
    }
    final stored = await _matchingWalletRow(record, wallet, storedEntry);
    if (stored == null) return _Restored.conflict;
    if (storedEntry.description == record.description &&
        stored.label == wallet.label) {
      return _Restored.unchanged;
    }
    final storedRevision = _revisionOf(storedEntry, stored);
    final restoredRevision = record.updatedAt > wallet.updatedAt
        ? record.updatedAt
        : wallet.updatedAt;
    // Older restored text never clobbers newer local text; two different texts
    // stamped with the same instant cannot be ordered at all.
    if (restoredRevision < storedRevision) return _Restored.unchanged;
    if (restoredRevision == storedRevision) return _Restored.conflict;
    await _writeWalletMetadata(
      entryId: record.entryId,
      walletId: wallet.walletId,
      description: record.description,
      label: wallet.label,
      updatedAt: restoredRevision,
    );
    return _Restored.applied;
  }

  /// The stored binding of [record], or null when the stored state is a
  /// different wallet rather than the same one restated.
  Future<KeychainManifestWalletBindingRow?> _matchingWalletRow(
    KeychainManifestEntry record,
    KeychainManifestWallet wallet,
    KeychainManifestEntryRow storedEntry,
  ) async {
    if (!_sameEntryShape(storedEntry, record)) return null;
    final bound = await _walletRowsOf(record.entryId);
    if (bound.length != 1 || bound.single.walletId != wallet.walletId) {
      return null;
    }
    final stored = bound.single;
    // The four-byte seed fingerprint that keys the entry id is a lookup hint,
    // so two descriptors can land on one entry. They are separate wallets and
    // must never be merged (spec 6.5).
    return stored.childSeedFingerprint == wallet.childSeedFingerprint.hex &&
            stored.network == wallet.network.name &&
            stored.scriptType == wallet.scriptType.name &&
            stored.provenance == wallet.provenance.name &&
            stored.seedPassphraseUsed == wallet.seedPassphraseUsed &&
            stored.descriptor == wallet.descriptor
        ? stored
        : null;
  }

  Future<void> _writeWalletMetadata({
    required String entryId,
    required String walletId,
    required String? description,
    required String? label,
    required int updatedAt,
  }) async {
    await (_database.update(
      _database.keychainManifestEntries,
    )..where((row) => row.entryId.equals(entryId))).write(
      KeychainManifestEntriesCompanion(
        description: Value(description),
        updatedAt: Value(updatedAt),
      ),
    );
    await (_database.update(
      _database.keychainManifestWalletBindings,
    )..where((row) => row.walletId.equals(walletId))).write(
      KeychainManifestWalletBindingsCompanion(
        label: Value(label),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<KeychainManifestEntryRow?> _entryRow(String entryId) =>
      (_database.select(
        _database.keychainManifestEntries,
      )..where((row) => row.entryId.equals(entryId))).getSingleOrNull();

  Future<KeychainManifestWalletBindingRow?> _walletRow(String walletId) =>
      (_database.select(
        _database.keychainManifestWalletBindings,
      )..where((row) => row.walletId.equals(walletId))).getSingleOrNull();

  Future<List<KeychainManifestWalletBindingRow>> _walletRowsOf(
    String entryId,
  ) => (_database.select(
    _database.keychainManifestWalletBindings,
  )..where((row) => row.entryId.equals(entryId))).get();

  Future<KeychainManifestNostrKeyRow?> _nostrRow(String entryId) =>
      (_database.select(
        _database.keychainManifestNostrKeys,
      )..where((row) => row.entryId.equals(entryId))).getSingleOrNull();

  Future<void> _insertEntry(KeychainManifestEntry entry) => _database
      .into(_database.keychainManifestEntries)
      .insert(
        KeychainManifestEntriesCompanion.insert(
          entryId: entry.entryId,
          parentFingerprint: entry.parentFingerprint.hex,
          derivationKind: entry.derivationKind.name,
          derivationPath: entry.derivationPath,
          description: Value(entry.description),
          createdAt: entry.createdAt,
          updatedAt: entry.updatedAt,
        ),
      );

  Future<void> _insertWallet(KeychainManifestWallet wallet) => _database
      .into(_database.keychainManifestWalletBindings)
      .insert(
        KeychainManifestWalletBindingsCompanion.insert(
          walletId: wallet.walletId,
          entryId: wallet.entryId,
          childSeedFingerprint: wallet.childSeedFingerprint.hex,
          network: wallet.network.name,
          scriptType: wallet.scriptType.name,
          provenance: wallet.provenance.name,
          seedPassphraseUsed: Value(wallet.seedPassphraseUsed),
          descriptor: Value(wallet.descriptor),
          label: Value(wallet.label),
          createdAt: wallet.createdAt,
          updatedAt: wallet.updatedAt,
        ),
      );

  KeychainManifestEntry _entryEntity(
    KeychainManifestEntryRow row,
    List<KeychainManifestMaterialization> items,
  ) => KeychainManifestEntry(
    parentFingerprint: Fingerprint(row.parentFingerprint),
    derivationKind: KeychainManifestDerivationKind.values.byName(
      row.derivationKind,
    ),
    derivationPath: row.derivationPath,
    description: row.description,
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
        provenance: WalletProvenance.values.byName(row.provenance),
        seedPassphraseUsed: row.seedPassphraseUsed,
        descriptor: row.descriptor,
        label: row.label,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  KeychainManifestNostrKey _nostrEntity(KeychainManifestNostrKeyRow row) =>
      KeychainManifestNostrKey(
        entryId: row.entryId,
        publicKeyHex: row.publicKeyHex,
        keyKind: KeychainManifestNostrKeyKind.values.byName(row.keyKind),
        purpose: row.purpose,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );
}

enum _Restored { applied, unchanged, conflict }

final class _ManifestConflictException implements Exception {
  const _ManifestConflictException();
}

bool _sameEntryShape(
  KeychainManifestEntryRow stored,
  KeychainManifestEntry record,
) =>
    stored.parentFingerprint == record.parentFingerprint.hex &&
    stored.derivationKind == record.derivationKind.name &&
    stored.derivationPath == record.derivationPath;

/// Entry and binding are written in lockstep, so the later of the two is the
/// revision the record actually stands at.
int _revisionOf(
  KeychainManifestEntryRow entry,
  KeychainManifestWalletBindingRow binding,
) => entry.updatedAt > binding.updatedAt ? entry.updatedAt : binding.updatedAt;

bool _isUserOwned(KeychainManifestWallet wallet) =>
    wallet.provenance == WalletProvenance.importedMnemonic ||
    wallet.provenance == WalletProvenance.defaultSeedPassphrase;

KeychainManifestWallet _walletOf(KeychainManifestEntry entry) =>
    entry.materializations.single as KeychainManifestWallet;

KeychainManifestWallet? _tryWalletOf(KeychainManifestEntry entry) {
  final item = entry.materializations.length == 1
      ? entry.materializations.single
      : null;
  return item is KeychainManifestWallet ? item : null;
}

String? _text(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _hasControlCharacter(String? value) =>
    value != null && KeychainManifestNostrKey.hasControlCharacter(value);

bool _sameWalletInventory(
  List<KeychainManifestEntry> left,
  List<KeychainManifestEntry> right,
) {
  if (left.length != right.length) return false;
  final leftById = {for (final entry in left) entry.entryId: entry};
  for (final candidate in right) {
    final current = leftById[candidate.entryId];
    if (current == null ||
        current.derivationPath != candidate.derivationPath ||
        current.materializations.length != 1 ||
        candidate.materializations.length != 1) {
      return false;
    }
    final a = _walletOf(current);
    final b = _walletOf(candidate);
    if (a.walletId != b.walletId ||
        a.childSeedFingerprint != b.childSeedFingerprint ||
        a.network != b.network ||
        a.scriptType != b.scriptType ||
        a.provenance != b.provenance ||
        a.seedPassphraseUsed != b.seedPassphraseUsed ||
        a.descriptor != b.descriptor ||
        a.label != b.label ||
        current.description != candidate.description) {
      return false;
    }
  }
  return true;
}
