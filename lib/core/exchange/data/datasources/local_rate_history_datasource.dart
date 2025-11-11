import 'package:bb_mobile/core/exchange/data/models/rate_history_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';

class LocalRateHistoryDatasource {
  final SqliteDatabase _db;

  LocalRateHistoryDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> storeRates({
    required List<RateModel> rates,
    required String fromCurrency,
    required String toCurrency,
    required String interval,
  }) async {
    if (rates.isEmpty) return;

    final rows =
        rates.map((rate) {
          return rate.toSqlite(
            fromCurrency: fromCurrency,
            toCurrency: toCurrency,
            interval: interval,
          );
        }).toList();

    await _db.batch((batch) {
      for (final row in rows) {
        batch.insert(
          _db.rateHistory,
          RateHistoryCompanion.insert(
            fromCurrency: row.fromCurrency,
            toCurrency: row.toCurrency,
            interval: row.interval,
            marketPrice: Value(row.marketPrice),
            price: Value(row.price),
            priceCurrency: Value(row.priceCurrency),
            precision: Value(row.precision),
            indexPrice: Value(row.indexPrice),
            userPrice: Value(row.userPrice),
            createdAt: row.createdAt,
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<DateTime?> getLatestRateDate({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
  }) async {
    final latest =
        await (_db.select(_db.rateHistory)
              ..where(
                (t) =>
                    t.fromCurrency.equals(fromCurrency) &
                    t.toCurrency.equals(toCurrency) &
                    t.interval.equals(interval),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(1))
            .getSingleOrNull();

    if (latest == null) return null;

    return DateTime.parse(latest.createdAt).toUtc();
  }

  Future<List<RateModel>> getRates({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _db.select(_db.rateHistory)..where(
      (t) =>
          t.fromCurrency.equals(fromCurrency) &
          t.toCurrency.equals(toCurrency) &
          t.interval.equals(interval),
    );

    if (fromDate != null) {
      final fromDateStr = fromDate.toUtc().toIso8601String();
      query =
          query..where((t) => t.createdAt.isBiggerOrEqualValue(fromDateStr));
    }

    if (toDate != null) {
      final toDateStr = toDate.toUtc().toIso8601String();
      query = query..where((t) => t.createdAt.isSmallerOrEqualValue(toDateStr));
    }

    query = query..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    final rows = await query.get();

    return rows.map((row) => RateModelSqlite.fromSqlite(row)).toList();
  }

  Future<void> cleanupOldRates({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    required Duration maxAge,
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge).toUtc();
    final cutoffDateStr = cutoffDate.toIso8601String();

    await (_db.delete(_db.rateHistory)..where(
      (t) =>
          t.fromCurrency.equals(fromCurrency) &
          t.toCurrency.equals(toCurrency) &
          t.interval.equals(interval) &
          t.createdAt.isSmallerThanValue(cutoffDateStr),
    )).go();
  }

  Future<void> deleteRates({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
  }) async {
    await (_db.delete(_db.rateHistory)..where(
      (t) =>
          t.fromCurrency.equals(fromCurrency) &
          t.toCurrency.equals(toCurrency) &
          t.interval.equals(interval),
    )).go();
  }
}
