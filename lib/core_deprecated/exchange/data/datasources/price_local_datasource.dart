import 'package:bb_mobile/core_deprecated/exchange/domain/entity/rate.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
import 'package:drift/drift.dart';

class PriceLocalDatasource {
  final SqliteDatabase _db;

  PriceLocalDatasource({required SqliteDatabase db}) : _db = db;

  Future<void> savePrices(List<Rate> prices) async {
    if (prices.isEmpty) return;

    final companions = prices.map((price) {
      return PricesCompanion.insert(
        fromCurrency: price.fromCurrency,
        toCurrency: price.toCurrency,
        interval: price.interval.value,
        createdAt: price.createdAt.toIso8601String(),
        marketPrice: Value(price.marketPrice),
        price: Value(price.price),
        priceCurrency: Value(price.priceCurrency),
        precision: Value(price.precision),
        indexPrice: Value(price.indexPrice),
        userPrice: Value(price.userPrice),
      );
    }).toList();

    await _db.batch((batch) {
      for (final companion in companions) {
        batch.insert(_db.prices, companion, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<List<Rate>> getPriceHistory({
    required String fromCurrency,
    required String toCurrency,
    required RateTimelineInterval interval,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var query = _db.select(_db.prices)
      ..where(
        (p) =>
            p.fromCurrency.equals(fromCurrency) &
            p.toCurrency.equals(toCurrency) &
            p.interval.equals(interval.value),
      );

    if (fromDate != null) {
      final fromDateStr = fromDate.toUtc().toIso8601String();
      query = query
        ..where((p) => p.createdAt.isBiggerOrEqualValue(fromDateStr));
    }
    if (toDate != null) {
      final toDateStr = toDate.toUtc().toIso8601String();
      query = query..where((p) => p.createdAt.isSmallerOrEqualValue(toDateStr));
    }

    query = query..orderBy([(p) => OrderingTerm.asc(p.createdAt)]);

    final rows = await query.get();

    return rows.map((row) {
      return Rate(
        fromCurrency: row.fromCurrency,
        toCurrency: row.toCurrency,
        interval: RateTimelineInterval.fromValue(row.interval),
        createdAt: DateTime.parse(row.createdAt),
        marketPrice: row.marketPrice,
        price: row.price,
        priceCurrency: row.priceCurrency,
        precision: row.precision,
        indexPrice: row.indexPrice,
        userPrice: row.userPrice,
      );
    }).toList();
  }

  Future<void> cleanupOldRates({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    required Duration maxAge,
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge).toUtc();
    final cutoffDateStr = cutoffDate.toIso8601String();

    await (_db.delete(_db.prices)..where(
          (p) =>
              p.fromCurrency.equals(fromCurrency) &
              p.toCurrency.equals(toCurrency) &
              p.interval.equals(interval) &
              p.createdAt.isSmallerThanValue(cutoffDateStr),
        ))
        .go();
  }

  Future<void> clearPrices({
    String? fromCurrency,
    String? toCurrency,
    String? interval,
  }) async {
    var query = _db.delete(_db.prices);

    if (fromCurrency != null && toCurrency != null && interval != null) {
      query = query
        ..where(
          (p) =>
              p.fromCurrency.equals(fromCurrency) &
              p.toCurrency.equals(toCurrency) &
              p.interval.equals(interval),
        );
    } else {
      if (fromCurrency != null) {
        query = query..where((p) => p.fromCurrency.equals(fromCurrency));
      }
      if (toCurrency != null) {
        query = query..where((p) => p.toCurrency.equals(toCurrency));
      }
      if (interval != null) {
        query = query..where((p) => p.interval.equals(interval));
      }
    }

    await query.go();
  }
}
