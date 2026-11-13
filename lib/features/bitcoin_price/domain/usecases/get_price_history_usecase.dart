import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// The mainnet price history in [currencyCode] for the chart, oldest first.
class GetPriceHistoryUsecase {
  final PriceHistoryReader _getPriceHistory;

  const GetPriceHistoryUsecase({required this._getPriceHistory});

  @useResult
  Future<Result<List<PricePoint>, PriceChartFailure>> execute({
    required String currencyCode,
  }) async {
    final currency = SupportedCurrency.tryFromCode(currencyCode);
    if (currency == null) {
      return Err(
        PriceChartUnexpectedFailure('Currency not available: $currencyCode'),
      );
    }
    // The chart is always the mainnet price.
    final history = await _getPriceHistory(
      network: BitcoinNetwork.mainnet,
      currency: currency,
    );
    switch (history) {
      case Ok(:final value):
        return Ok(value);
      case Err(:final failure):
        log.warning('Price history unavailable: ${failure.runtimeType}');
        return const Err(PriceChartLoadFailure());
    }
  }
}
