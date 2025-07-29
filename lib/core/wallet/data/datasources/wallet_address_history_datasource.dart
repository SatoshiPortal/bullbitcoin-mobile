import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/mappers/wallet_address_mapper.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_address_model.dart';
import 'package:drift/drift.dart';

class WalletAddressHistoryDatasource {
  final SqliteDatabase _db;

  WalletAddressHistoryDatasource({required SqliteDatabase db}) : _db = db;

  /// Insert a wallet address in the database.
  ///
  /// If the address already exists, it will be updated (upsert).
  Future<void> store(WalletAddressModel walletAddress) async {
    final addressHistoryRow = WalletAddressMapper.toSqliteCompanion(
      walletAddress,
    );
    await _db
        .into(_db.walletAddresses)
        .insertOnConflictUpdate(addressHistoryRow);
  }

  /// Select a wallet address from the database.
  Future<WalletAddressModel?> fetch(String address) async {
    final walletAddress =
        await _db.managers.walletAddresses
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
    int? fromIndex,
    bool isChange = false,
    required bool descending,
  }) async {
    // We want to fetch them in descending order by index
    final query =
        _db.select(_db.walletAddresses)
          ..where(
            (t) =>
                t.walletId.equals(walletId) &
                t.isChange.equals(isChange) &
                (fromIndex != null
                    ? descending
                        ? t.index.isSmallerOrEqualValue(fromIndex)
                        : t.index.isBiggerOrEqualValue(fromIndex)
                    : const Constant(true)),
          )
          ..orderBy([
            (t) =>
                descending
                    ? OrderingTerm.desc(t.index)
                    : OrderingTerm.asc(t.index),
          ]);

    if (limit != null) query.limit(limit);

    final rows = await query.get();

    return rows.map((row) {
      return WalletAddressMapper.fromSqliteRow(row);
    }).toList();
  }
}
