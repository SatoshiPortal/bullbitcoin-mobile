import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

/// Stands in for `Pricer.getIndexPrice`: answers [fiatAmount] in the
/// requested currency, or [failure] when set, and records each request.
class FakeIndexPriceReader {
  double fiatAmount;
  PricerFailure? failure;
  DateTime fetchedAt = DateTime.utc(2026, 11, 4, 12);
  final List<({BitcoinNetwork network, SupportedCurrency currency})> requests =
      [];

  FakeIndexPriceReader({this.fiatAmount = 100000, this.failure});

  Future<Result<BitcoinPrice, PricerFailure>> call({
    required BitcoinNetwork network,
    required SupportedCurrency currency,
  }) async {
    requests.add((network: network, currency: currency));
    final failure = this.failure;
    if (failure != null) return Err(failure);
    return Ok(
      BitcoinPrice(
        currency: currency,
        fiatAmount: fiatAmount,
        fetchedAt: fetchedAt,
      ),
    );
  }
}
