import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/mappers/address_details_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/address_details_model.dart';
import 'package:drift/drift.dart';

class AddressHistoryDatasource {
  final SqliteDatabase _db;

  AddressHistoryDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> store(AddressDetailsModel addressInfo) async {
    final addressHistoryRow = AddressDetailsMapper.modelToSqliteCompanion(
      addressInfo,
    );
    await _db
        .into(_db.addressHistory)
        .insertOnConflictUpdate(addressHistoryRow);
  }

  Future<List<AddressDetailsModel>> getByWalletId(
    String walletId, {
    int? limit,
    int? offset,
    bool isChange = false,
  }) async {
    // We want to fetch them in descending order by index
    final query =
        _db.select(_db.addressHistory)
          ..where(
            (t) => t.walletId.equals(walletId) & t.isChange.equals(isChange),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.index)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    final rows = await query.get();

    return rows.map((row) {
      return AddressDetailsMapper.sqliteRowToModel(row);
    }).toList();
  }
}
