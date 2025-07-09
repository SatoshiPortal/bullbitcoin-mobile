import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';

class WalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  WalletMetadataDatasource({required SqliteDatabase sqliteDatasource})
    : _sqlite = sqliteDatasource;

  Future<void> store(WalletMetadataModel metadata) async {
    await _sqlite
        .into(_sqlite.walletMetadatas)
        .insertOnConflictUpdate(metadata.toSqlite());
  }

  Future<WalletMetadataModel?> fetch(String walletId) async {
    final row =
        await _sqlite.managers.walletMetadatas
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
