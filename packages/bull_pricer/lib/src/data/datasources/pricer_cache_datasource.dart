import 'package:bull_pricer/src/data/models/price_model.dart';
import 'package:bull_pricer/src/data/pricer_database.dart';
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
}
