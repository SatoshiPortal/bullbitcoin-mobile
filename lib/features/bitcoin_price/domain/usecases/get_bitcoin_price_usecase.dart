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
  Future<Result<double, PricerFailure>> execute({
    required String currencyCode,
  }) async {
    final Environment environment;
    try {
      environment = await _environment.readActiveEnvironment();
    } catch (e, st) {
      log.severe(
        message: 'Failed to read the settings for the bitcoin price',
        error: e,
        trace: st,
      );
      return Err(PricerUnexpectedFailure('$e'));
    }
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return Err(
        PricerUnexpectedFailure('Currency not available: $currencyCode'),
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
    return price.map((value) => value.fiatAmount);
  }
}
