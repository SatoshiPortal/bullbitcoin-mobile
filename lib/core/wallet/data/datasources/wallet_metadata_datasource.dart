import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_metadata_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:drift/drift.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  final StreamController<void> _preferenceChanges =
      StreamController<void>.broadcast(sync: true);
  final StreamController<void> _catalogChanges =
      StreamController<void>.broadcast(sync: true);

  WalletMetadataDatasource({required this._sqlite});

  Stream<void> get preferenceChanges => _preferenceChanges.stream;
  Stream<void> get catalogChanges => _catalogChanges.stream;

  Future<void> store(WalletMetadataModel metadata) async {
    final previous = await fetch(metadata.id);
    await _store(metadata);
    if (_preferencesDiffer(previous, metadata)) {
      _preferenceChanges.add(null);
    }
    if (_definitionsDiffer(previous, metadata)) _catalogChanges.add(null);
  }

  Future<void> _store(WalletMetadataModel metadata) async {
    await _sqlite.transaction(() async {
      await _sqlite
          .into(_sqlite.walletMetadatas)
          .insertOnConflictUpdate(metadata.toSqlite());
      await (_sqlite.delete(
        _sqlite.walletSigners,
      )..where((row) => row.walletId.equals(metadata.id))).go();
      final signers = metadata.signersToSqlite();
      if (signers.isNotEmpty) {
        await _sqlite.batch(
          (batch) => batch.insertAll(_sqlite.walletSigners, signers),
        );
      }
      final descriptorKeys = metadata.descriptorKeysToSqlite();
      if (descriptorKeys.isNotEmpty) {
        await _sqlite.batch(
          (batch) =>
              batch.insertAll(_sqlite.walletDescriptorKeys, descriptorKeys),
        );
      }
    });
  }

  Future<void> storeAll(List<WalletMetadataModel> metadata) async {
    if (metadata.isEmpty) return;
    final previous = {for (final item in await fetchAll()) item.id: item};
    await _sqlite.transaction(() async {
      for (final item in metadata) {
        await _store(item);
      }
    });
    if (metadata.any((item) => _preferencesDiffer(previous[item.id], item))) {
      _preferenceChanges.add(null);
    }
    if (metadata.any((item) => _definitionsDiffer(previous[item.id], item))) {
      _catalogChanges.add(null);
    }
  }

  /// Applies recovered preference fields only while the classified local
  /// preference projection is still current.
  Future<Set<String>> storeRecoveredPreferencesConditionally(
    List<WalletMetadataPreferenceRecoveryUpdate> updates,
  ) async {
    if (updates.isEmpty) return const {};
    final conflicted = <String>{};
    var changed = false;
    await _sqlite.transaction(() async {
      for (final update in updates) {
        final current = await fetch(update.walletRef);
        if (current == null || !_matchesExpectedPreferences(current, update)) {
          conflicted.add(update.walletRef);
          continue;
        }
        final recovered = current.copyWith(
          label: update.recoveredLabel,
          hideOnHome: update.recoveredHideOnHome,
          autoSweepEnabled: update.recoveredAutoSweepEnabled,
        );
        if (_preferencesDiffer(current, recovered)) changed = true;
        await _store(recovered);
      }
    });
    if (changed) _preferenceChanges.add(null);
    return Set.unmodifiable(conflicted);
  }

  Future<WalletMetadataModel?> fetch(String walletId) =>
      _sqlite.transaction(() async {
        final row = await _sqlite.managers.walletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

        if (row == null) return null;
        final signerRows = await _fetchSigners(walletId);
        final descriptorKeyRows = await _fetchDescriptorKeys(walletId);
        return WalletMetadataMapper.fromSqlite(
          row,
          signerRows,
          descriptorKeyRows,
        );
      });

  Future<List<WalletMetadataModel>> fetchAll() => _sqlite.transaction(() async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    final signers = await _sqlite.managers.walletSigners.get();
    final descriptorKeys = await _sqlite.managers.walletDescriptorKeys.get();
    final signersByWallet = <String, List<WalletSignerRow>>{};
    final keysByWallet = <String, List<WalletDescriptorKeyRow>>{};
    for (final signer in signers) {
      signersByWallet.putIfAbsent(signer.walletId, () => []).add(signer);
    }
    for (final key in descriptorKeys) {
      keysByWallet.putIfAbsent(key.walletId, () => []).add(key);
    }
    return [
      for (final row in rows)
        WalletMetadataMapper.fromSqlite(
          row,
          signersByWallet[row.id] ?? const [],
          keysByWallet[row.id] ?? const [],
        ),
    ];
  });

  Future<void> delete(String walletId) async {
    final previous = await fetch(walletId);
    final deleted = await _sqlite.managers.walletMetadatas
        .filter((row) => row.id(walletId))
        .delete();
    if (deleted > 0 &&
        previous != null &&
        _hasRepresentedPreferences(previous)) {
      _preferenceChanges.add(null);
    }
    if (deleted > 0 && previous != null && _isBackedUpDefinition(previous)) {
      _catalogChanges.add(null);
    }
  }

  Future<bool> updateSignerDevice({
    required String walletId,
    required String signerId,
    required Signer signer,
    required SignerDevice? signerDevice,
  }) async {
    final updatedRows =
        await (_sqlite.update(_sqlite.walletSigners)..where(
              (row) => row.walletId.equals(walletId) & row.id.equals(signerId),
            ))
            .write(
              WalletSignersCompanion(
                signer: Value(signer),
                signerDevice: Value(signerDevice),
              ),
            );
    return updatedRows == 1;
  }

  Future<bool> updateSignerRegistrationName({
    required String walletId,
    required String signerId,
    required String registrationName,
  }) async {
    final updatedRows =
        await (_sqlite.update(_sqlite.walletSigners)..where(
              (row) => row.walletId.equals(walletId) & row.id.equals(signerId),
            ))
            .write(
              WalletSignersCompanion(registrationName: Value(registrationName)),
            );
    return updatedRows == 1;
  }

  Future<bool> updateSyncedAt({
    required String walletId,
    required DateTime syncedAt,
  }) async {
    final updatedRows =
        await (_sqlite.update(_sqlite.walletMetadatas)
              ..where((row) => row.id.equals(walletId)))
            .write(WalletMetadatasCompanion(syncedAt: Value(syncedAt)));
    return updatedRows == 1;
  }

  Future<List<WalletSignerRow>> _fetchSigners(String walletId) async {
    final query = _sqlite.select(_sqlite.walletSigners)
      ..where((row) => row.walletId.equals(walletId))
      ..orderBy([(row) => OrderingTerm.asc(row.position)]);
    return query.get();
  }

  Future<List<WalletDescriptorKeyRow>> _fetchDescriptorKeys(
    String walletId,
  ) async {
    final query = _sqlite.select(_sqlite.walletDescriptorKeys)
      ..where((row) => row.walletId.equals(walletId))
      ..orderBy([(row) => OrderingTerm.asc(row.position)]);
    return query.get();
  }
}

final class WalletMetadataPreferenceRecoveryUpdate {
  final String walletRef;
  final String? expectedLabel;
  final bool? expectedHideOnHome;
  final bool? expectedAutoSweepEnabled;
  final String? recoveredLabel;
  final bool? recoveredHideOnHome;
  final bool? recoveredAutoSweepEnabled;

  const WalletMetadataPreferenceRecoveryUpdate({
    required this.walletRef,
    required this.expectedLabel,
    required this.expectedHideOnHome,
    required this.expectedAutoSweepEnabled,
    required this.recoveredLabel,
    required this.recoveredHideOnHome,
    required this.recoveredAutoSweepEnabled,
  });
}

bool _matchesExpectedPreferences(
  WalletMetadataModel current,
  WalletMetadataPreferenceRecoveryUpdate update,
) =>
    current.label == update.expectedLabel &&
    current.hideOnHome == update.expectedHideOnHome &&
    current.autoSweepEnabled == update.expectedAutoSweepEnabled;

bool _preferencesDiffer(
  WalletMetadataModel? previous,
  WalletMetadataModel current,
) {
  if (previous == null) return _hasRepresentedPreferences(current);
  return previous.label != current.label ||
      previous.hideOnHome != current.hideOnHome ||
      previous.autoSweepEnabled != current.autoSweepEnabled;
}

bool _hasRepresentedPreferences(WalletMetadataModel metadata) {
  return metadata.label != null ||
      metadata.hideOnHome != null ||
      metadata.autoSweepEnabled != null;
}

/// A backed-up definition changed when its descriptor, any signer (device or
/// key material), birthday or provenance facts changed. Signers are compared
/// as whole lists: the normalized signer rows replace the former single
/// fingerprint/device pair.
bool _definitionsDiffer(
  WalletMetadataModel? previous,
  WalletMetadataModel current,
) {
  if (previous != null &&
      _isBackedUpDefinition(previous) != _isBackedUpDefinition(current)) {
    return true;
  }
  if (!_isBackedUpDefinition(current)) return false;
  return previous == null ||
      previous.publicDescriptor != current.publicDescriptor ||
      previous.signers != current.signers ||
      previous.birthday != current.birthday ||
      previous.provenance != current.provenance ||
      previous.seedPassphraseUsed != current.seedPassphraseUsed;
}

bool _isBackedUpDefinition(WalletMetadataModel metadata) =>
    metadata.isBitcoin &&
    (metadata.provenance == WalletProvenance.watchOnly ||
        metadata.provenance == WalletProvenance.externalSigner);
