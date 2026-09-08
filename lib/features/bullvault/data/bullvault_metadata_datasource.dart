import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

final class BullVaultMetadataDatasource {
  final SqliteDatabase _database;

  const BullVaultMetadataDatasource(this._database);

  Future<T> transaction<T>(Future<T> Function() action) =>
      _database.transaction(action);

  Future<void> save(BullVaultRecordModel model) async {
    await _database
        .into(_database.bullVaultRecords)
        .insertOnConflictUpdate(model);
  }

  Future<void> delete(String walletId) async {
    await (_database.delete(
      _database.bullVaultRecords,
    )..where((row) => row.walletId.equals(walletId))).go();
  }

  Future<BullVaultRecordModel?> load(String walletId) => (_database.select(
    _database.bullVaultRecords,
  )..where((row) => row.walletId.equals(walletId))).getSingleOrNull();

  Future<List<BullVaultRecordModel>> loadLineage(String lineageId) =>
      (_database.select(_database.bullVaultRecords)
            ..where((row) => row.lineageId.equals(lineageId))
            ..orderBy([(row) => OrderingTerm.asc(row.vaultGeneration)]))
          .get();

  Future<List<BullVaultRecordModel>> loadPendingInitial() =>
      (_database.select(_database.bullVaultRecords)..where(
            (row) =>
                row.vaultGeneration.equals(0) & row.status.equals('pending'),
          ))
          .get();

  Future<Map<String, String>> migrationDestinations(
    Set<String> walletIds,
  ) async {
    if (walletIds.isEmpty) return const {};
    final previous = _database.alias(_database.bullVaultRecords, 'previous');
    final active = _database.alias(_database.bullVaultRecords, 'active');
    final rows =
        await (_database.selectOnly(previous)
              ..addColumns([previous.walletId, active.walletId])
              ..join([
                innerJoin(
                  active,
                  active.lineageId.equalsExp(previous.lineageId),
                ),
              ])
              ..where(
                active.walletId.isIn(walletIds) &
                    active.status.equals('active') &
                    previous.status.isIn(['migrating', 'cancelled']),
              ))
            .get();
    return {
      for (final row in rows)
        row.read(previous.walletId)!: row.read(active.walletId)!,
    };
  }

  Future<Set<int>> loadGenerationReservations(String lineageId) async => {
    for (final row in await (_database.select(
      _database.bullVaultGenerationReservations,
    )..where((row) => row.lineageId.equals(lineageId))).get())
      row.generation,
  };

  Future<void> saveGenerationReservations(
    String lineageId,
    Set<int> generations,
  ) => transaction(() async {
    await (_database.delete(
      _database.bullVaultGenerationReservations,
    )..where((row) => row.lineageId.equals(lineageId))).go();
    for (final generation in generations) {
      await _database
          .into(_database.bullVaultGenerationReservations)
          .insert(
            BullVaultGenerationReservationsCompanion.insert(
              lineageId: lineageId,
              generation: generation,
            ),
          );
    }
  });

  Future<void> setWalletHidden(String walletId, bool hidden) async {
    final changed =
        await (_database.update(_database.walletMetadatas)
              ..where((row) => row.id.equals(walletId)))
            .write(WalletMetadatasCompanion(isHidden: Value(hidden)));
    if (changed != 1) throw const BullVaultWalletNotFoundException();
  }
}

final class BullVaultWalletNotFoundException implements Exception {
  const BullVaultWalletNotFoundException();
}
