part of 'package:bb_mobile/core/storage/sqlite_database.dart';

@DriftAccessor(tables: [Prices])
class PricesLocalDatasource extends DatabaseAccessor<SqliteDatabase> with _$PricesLocalDatasourceMixin {
  PricesLocalDatasource(super.attachedDatabase);

  Future<void> storeBatch(List<PriceRow> rows) {
    return batch((batch) {
      for (final row in rows) {
        batch.insert(prices, row.toCompanion(true), mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<List<PriceRow>> fetchHistory({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    String? fromDateIso,
    String? toDateIso,
  }) async {
    var query = select(prices)
      ..where(
        (p) =>
            p.fromCurrency.equals(fromCurrency) &
            p.toCurrency.equals(toCurrency) &
            p.interval.equals(interval),
      );

    if (fromDateIso != null) {
      query = query..where((p) => p.createdAt.isBiggerOrEqualValue(fromDateIso));
    }
    if (toDateIso != null) {
      query = query..where((p) => p.createdAt.isSmallerOrEqualValue(toDateIso));
    }

    query = query..orderBy([(p) => OrderingTerm.asc(p.createdAt)]);

    return query.get();
  }

  Future<void> trashOlderThan({
    required String fromCurrency,
    required String toCurrency,
    required String interval,
    required String cutoffDateIso,
  }) {
    return (delete(prices)
          ..where(
            (p) =>
                p.fromCurrency.equals(fromCurrency) &
                p.toCurrency.equals(toCurrency) &
                p.interval.equals(interval) &
                p.createdAt.isSmallerThanValue(cutoffDateIso),
          ))
        .go();
  }

  Future<void> trashByFilters({
    String? fromCurrency,
    String? toCurrency,
    String? interval,
  }) async {
    var query = delete(prices);

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
