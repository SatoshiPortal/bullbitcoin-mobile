import 'package:bull_pricer/src/data/datasources/pricer_cache_datasource.dart';
import 'package:bull_pricer/src/data/pricer_database.dart';
import 'package:bull_pricer/src/data/pricer_repository.dart';
import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:bull_pricer/src/domain/pricer_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

abstract final class Pricer {
  static PricerRepository? _repository;

  static Future<void> init({required String databasePath}) async {
    if (_repository != null) return;

    final database = PricerDatabase.open(databasePath);

    _repository = PricerRepository(
      pricerCacheDatasource: PricerCacheDatasource(database),
    );
  }

  /// The approximate price of one bitcoin, the same for everyone; works
  /// without login.
  @useResult
  static Future<Result<BitcoinPrice, PricerFailure>> getIndexPrice({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) => _call(
    (repository) => repository.indexPrice(network: network, currency: currency),
  );

  static Future<Result<BitcoinPrice, PricerFailure>> _call(
    Future<Result<BitcoinPrice, PricerFailure>> Function(PricerRepository)
    action,
  ) {
    final repository = _repository;
    if (repository == null) {
      throw StateError('Pricer.init was not called');
    }
    return action(repository);
  }
}
