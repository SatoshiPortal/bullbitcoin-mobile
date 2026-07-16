import 'dart:async';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;
  final StreamController<void> _preferenceChanges =
      StreamController<void>.broadcast(sync: true);

  WalletMetadataDatasource({required this._sqlite});

  Stream<void> get preferenceChanges => _preferenceChanges.stream;

  Future<void> store(WalletMetadataModel metadata) async {
    final previous = await fetch(metadata.id);
    await _store(metadata);
    if (_preferencesDiffer(previous, metadata)) {
      _preferenceChanges.add(null);
    }
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
  }
}

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
