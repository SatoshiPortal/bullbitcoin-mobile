import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The price of one bitcoin in [currencyCode], on the active network.
class GetBitcoinPriceUsecase {
  final ActiveEnvironmentReader _environment;
  final IndexPriceReader _getIndexPrice;

  const GetBitcoinPriceUsecase({
    required this._environment,
    required this._getIndexPrice,
  });

  @useResult
  Future<Result<double, BitcoinPriceFailure>> execute({
    required String currencyCode,
  }) async {
    final environment = await _environment.readActiveEnvironment();
    switch (environment) {
      case Ok(:final value):
        return _quote(value, currencyCode);
      case Err(:final failure):
        log.warning(
          'Failed to read the active environment for the bitcoin price',
        );
        return Err(BitcoinPricePreferencesFailure(failure.logMessage));
    }
  }

  Future<Result<double, BitcoinPriceFailure>> _quote(
    Environment environment,
    String currencyCode,
  ) async {
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return Err(
        BitcoinPriceUnexpectedFailure('Currency not available: $currencyCode'),
      );
    }
    final price = await _getIndexPrice(
      network: switch (environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
      currency: currency,
    );
    if (price case Err(:final failure)) {
      log.warning('Bitcoin price unavailable: ${failure.runtimeType}');
    }
    return price
        .map((value) => value.fiatAmount)
        .mapErr(
          (failure) => switch (failure) {
            PricerNetworkFailure() => BitcoinPriceNetworkFailure(
              failure.logMessage,
            ),
            PricerRateLimitedFailure() || PricerUnsupportedNetworkFailure() =>
              BitcoinPriceRateUnavailableFailure(failure.logMessage),
            PricerUnexpectedFailure() => BitcoinPriceUnexpectedFailure(
              failure.logMessage,
            ),
          },
        );
  }
}
