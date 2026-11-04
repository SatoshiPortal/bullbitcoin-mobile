import 'package:bull_pricer/src/data/models/price_model.dart';
import 'package:bull_pricer/src/data/models/price_point_model.dart';
import 'package:bull_pricer/src/data/pricer_database.dart';
import 'package:bull_pricer/src/domain/entities/price_history_interval.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:drift/drift.dart';
import 'package:primitives/primitives.dart';

/// The last price fetched for each network and currency, in the pricer's own
/// database.
final class PricerCacheDatasource {
  final PricerDatabase _db;

  const PricerCacheDatasource(this._db);

  /// The cached price, or null if there is none.
  Future<PriceModel?> find(
    BitcoinNetwork network,
    SupportedCurrency currency,
  ) async {
    final row =
        await (_db.select(_db.cachedPrices)..where(
              (p) =>
                  p.network.equals(network.name) &
                  p.currency.equals(currency.code),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return PriceModel(
      network: network,
      currency: currency,
      fiatAmount: row.fiatAmount,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(
        row.fetchedAt,
        isUtc: true,
      ),
    );
  }

  /// Remembers the fetched price, replacing the previous one for the same
  /// network and currency.
  Future<void> save(PriceModel price) async {
    await _db
        .into(_db.cachedPrices)
        .insertOnConflictUpdate(
          CachedPricesCompanion.insert(
            network: price.network.name,
            currency: price.currency.code,
            fiatAmount: price.fiatAmount,
            fetchedAt: price.fetchedAt.millisecondsSinceEpoch,
          ),
        );
  }

  /// The stored points of a price history from [from] on, oldest first.
  Future<List<PricePointModel>> findHistory(
    BitcoinNetwork network,
    SupportedCurrency currency,
    PriceHistoryInterval interval, {
    required DateTime from,
  }) async {
    final rows =
        await (_db.select(_db.cachedPricePoints)
              ..where(
                (p) =>
                    p.network.equals(network.name) &
                    p.currency.equals(currency.code) &
                    p.interval.equals(interval.code) &
                    p.time.isBiggerOrEqualValue(from.millisecondsSinceEpoch),
              )
              ..orderBy([(p) => OrderingTerm.asc(p.time)]))
            .get();
    return [
      for (final row in rows)
        PricePointModel(
          network: network,
          currency: currency,
          interval: interval,
          time: DateTime.fromMillisecondsSinceEpoch(row.time, isUtc: true),
          fiatAmount: row.fiatAmount,
        ),
    ];
  }

  /// Replaces the stored points of a price history with [points].
  Future<void> replaceHistory(
    BitcoinNetwork network,
    SupportedCurrency currency,
    PriceHistoryInterval interval,
    List<PricePointModel> points,
  ) async {
    await _db.transaction(() async {
      await (_db.delete(_db.cachedPricePoints)..where(
            (p) =>
                p.network.equals(network.name) &
                p.currency.equals(currency.code) &
                p.interval.equals(interval.code),
          ))
          .go();
      await _db.batch((batch) {
        batch.insertAll(_db.cachedPricePoints, [
          for (final point in points)
            CachedPricePointsCompanion.insert(
              network: network.name,
              currency: currency.code,
              interval: interval.code,
              time: point.time.millisecondsSinceEpoch,
              fiatAmount: point.fiatAmount,
            ),
        ], mode: InsertMode.insertOrReplace);
      });
    });
  }
}
