import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

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
    final companion = metadata.toSqlite();
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insertOnConflictUpdate(companion);
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

  Future<WalletMetadataModel?> fetch(String walletId) async {
    final row = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .getSingleOrNull();

    if (row == null) return null;
    return WalletMetadataModelMapper.fromSqlite(row);
  }

  Future<List<WalletMetadataModel>> fetchAll() async {
    final rows = await _sqlite.managers.walletMetadatas.get();
    return rows.map((e) => WalletMetadataModelMapper.fromSqlite(e)).toList();
  }

  Future<void> delete(String walletId) async {
    final previous = await fetch(walletId);
    final deleted = await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
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
      previous.externalPublicDescriptor != current.externalPublicDescriptor ||
      previous.internalPublicDescriptor != current.internalPublicDescriptor ||
      previous.masterFingerprint != current.masterFingerprint ||
      previous.signerDevice != current.signerDevice ||
      previous.birthday != current.birthday ||
      previous.provenance != current.provenance ||
      previous.seedPassphraseUsed != current.seedPassphraseUsed;
}

bool _isBackedUpDefinition(WalletMetadataModel metadata) =>
    metadata.isBitcoin &&
    (metadata.provenance == WalletProvenance.watchOnly ||
        metadata.provenance == WalletProvenance.externalSigner);
