import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  WalletMetadataDatasource({required this._sqlite});

  /// Claims a new catalog row without replacing an existing wallet.
  Future<void> insert(WalletMetadataModel metadata) async {
    try {
      await _sqlite.into(_sqlite.walletMetadatas).insert(metadata.toSqlite());
    } on SqliteException catch (error) {
      if (error.extendedResultCode ==
          SqlExtendedError.SQLITE_CONSTRAINT_PRIMARYKEY) {
        throw WalletAlreadyExistsException(metadata.id);
      }
      rethrow;
    }
  }

  Future<void> store(WalletMetadataModel metadata) async {
    final companion = metadata.toSqlite();
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insertOnConflictUpdate(companion);
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
    await _sqlite.managers.walletMetadatas
        .filter((e) => e.id(walletId))
        .delete();
  }
}
