import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:drift/drift.dart';

class WalletAddressHistoryDatasource {
  final SqliteDatabase _db;

  WalletAddressHistoryDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> create(WalletAddressModel walletAddress) async {
    final addressHistoryRow = WalletAddressMapper.toSqliteCompanion(
      walletAddress,
    );
    await _db.into(_db.walletAddressHistory).insert(addressHistoryRow);
  }

  Future<void> update(WalletAddressModel walletAddress) async {
    final addressHistoryRow = WalletAddressMapper.toSqliteCompanion(
      walletAddress,
    );

    final updatedRows = await (_db.update(_db.walletAddressHistory)..where(
      (t) =>
          t.walletId.equals(walletAddress.walletId) &
          t.index.equals(walletAddress.index) &
          t.isChange.equals(walletAddress.isChange),
    )).write(addressHistoryRow);

    if (updatedRows == 0) {
      throw StateError(
        'No address found for walletId: ${walletAddress.walletId}, '
        'index: ${walletAddress.index}, isChange: ${walletAddress.isChange}',
      );
    }
  }

  Future<WalletAddressModel?> get(String address) async {
    final walletAddress =
        await _db.managers.walletAddressHistory
            .filter((t) => t.address(address))
            .getSingleOrNull();

    if (walletAddress == null) {
      return null;
    }

    return WalletAddressMapper.fromSqliteRow(walletAddress);
  }

  Future<List<WalletAddressModel>> getByWalletId(
    String walletId, {
    int? limit,
    int? offset,
    bool isChange = false,
    required bool descending,
  }) async {
    // We want to fetch them in descending order by index
    final query =
        _db.select(_db.walletAddressHistory)
          ..where(
            (t) => t.walletId.equals(walletId) & t.isChange.equals(isChange),
          )
          ..orderBy([
            (t) =>
                descending
                    ? OrderingTerm.desc(t.index)
                    : OrderingTerm.asc(t.index),
          ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    final rows = await query.get();

    return rows.map((row) {
      return WalletAddressMapper.fromSqliteRow(row);
    }).toList();
  }
}
