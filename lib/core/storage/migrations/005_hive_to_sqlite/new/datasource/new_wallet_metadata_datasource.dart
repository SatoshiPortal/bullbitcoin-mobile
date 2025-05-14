import 'package:bb_mobile/core/storage/migrations/005_hive_to_sqlite/new/models/new_wallet_metadata_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';

class NewWalletMetadataDatasource {
  final SqliteDatabase _sqlite;

  NewWalletMetadataDatasource({required SqliteDatabase sqliteDatasource})
    : _sqlite = sqliteDatasource;

  Future<void> store(NewWalletMetadataModel metadata) async {
    await _sqlite
        .into(_sqlite.v5MigrateWalletMetadatas)
        .insertOnConflictUpdate(metadata.toSqlite());
  }

  Future<NewWalletMetadataModel?> fetch(String walletId) async {
    final row =
        await _sqlite.managers.v5MigrateWalletMetadatas
            .filter((e) => e.id(walletId))
            .getSingleOrNull();

    if (row == null) return null;
    return NewWalletMetadataModelMapper.fromSqlite(row);
  }

  Future<List<NewWalletMetadataModel>> fetchAll() async {
    final rows = await _sqlite.managers.v5MigrateWalletMetadatas.get();
    return rows.map((e) => NewWalletMetadataModelMapper.fromSqlite(e)).toList();
  }
}
