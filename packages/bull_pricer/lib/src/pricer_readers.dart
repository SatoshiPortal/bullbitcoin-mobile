import 'package:bull_pricer/src/domain/entities/bitcoin_price.dart';
import 'package:bull_pricer/src/domain/entities/price_point.dart';
import 'package:bull_pricer/src/domain/entities/supported_currency.dart';
import 'package:bull_pricer/src/domain/pricer_failure.dart';
import 'package:primitives/primitives.dart';

/// The shape of `Pricer.getIndexPrice`, for code that takes it as a
/// dependency so tests can replace it.
typedef IndexPriceReader =
    Future<Result<BitcoinPrice, PricerFailure>> Function({
      required BitcoinNetwork network,
      required SupportedCurrency currency,
    });

/// The shape of `Pricer.getPriceHistory`, for code that takes it as a
/// dependency so tests can replace it.
typedef PriceHistoryReader =
    Future<Result<List<PricePoint>, PricerFailure>> Function({
      required BitcoinNetwork network,
      required SupportedCurrency currency,
    });
