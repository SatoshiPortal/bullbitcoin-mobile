import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class OrderSwapLocalDatasource {
  final SqliteDatabase _database;

  const OrderSwapLocalDatasource(this._database);

  Future<void> save(OrderSwapsCompanion order) =>
      _database.into(_database.orderSwaps).insertOnConflictUpdate(order);

  Future<OrderSwapRow?> getByLocalId(String localId) => (_database.select(
    _database.orderSwaps,
  )..where((table) => table.localId.equals(localId))).getSingleOrNull();

  Stream<OrderSwapRow> watchByLocalId(String localId) => (_database.select(
    _database.orderSwaps,
  )..where((table) => table.localId.equals(localId))).watchSingle();

  Future<OrderSwapRow?> getByOrderId(String orderId) => (_database.select(
    _database.orderSwaps,
  )..where((table) => table.orderId.equals(orderId))).getSingleOrNull();

  Future<OrderSwapRow?> getMatchingActiveRequest({
    required String purpose,
    required String environment,
    required String inNetwork,
    required String outNetwork,
    required bool isInAmountFixed,
    required int requestedAmountSat,
    required String destination,
    required String? sourceWalletId,
    required Iterable<String> activeStatuses,
  }) {
    final statuses = activeStatuses.toList(growable: false);
    if (statuses.isEmpty) return Future.value();
    final query = _database.select(_database.orderSwaps)
      ..where(
        (table) =>
            table.purpose.equals(purpose) &
            table.environment.equals(environment) &
            table.inNetwork.equals(inNetwork) &
            table.outNetwork.equals(outNetwork) &
            table.isInAmountFixed.equals(isInAmountFixed) &
            table.requestedAmountSat.equals(requestedAmountSat) &
            table.destination.equals(destination) &
            (sourceWalletId == null
                ? table.sourceWalletId.isNull()
                : table.sourceWalletId.equals(sourceWalletId)) &
            table.localStatus.isIn(statuses),
      )
      ..orderBy([(table) => OrderingTerm.asc(table.createdAt)])
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> delete(String localId) => (_database.delete(
    _database.orderSwaps,
  )..where((table) => table.localId.equals(localId))).go();

  Future<List<OrderSwapRow>> getAll({String? walletId}) {
    final query = _database.select(_database.orderSwaps);
    if (walletId != null) {
      query.where(
        (table) =>
            table.sourceWalletId.equals(walletId) |
            table.destinationWalletId.equals(walletId),
      );
    }
    query.orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
    return query.get();
  }

  Future<List<OrderSwapRow>> getByLocalStatuses(Iterable<String> statuses) {
    final values = statuses.toList(growable: false);
    if (values.isEmpty) return Future.value(const []);
    return (_database.select(_database.orderSwaps)
          ..where((table) => table.localStatus.isIn(values))
          ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
        .get();
  }

  Future<List<OrderSwapRow>> getCompletedWithoutLabels(String purpose) =>
      (_database.select(_database.orderSwaps)
            ..where(
              (table) =>
                  table.purpose.equals(purpose) &
                  table.localStatus.equals('completed') &
                  table.labelsAppliedAt.isNull(),
            )
            ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
          .get();
}
