import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  final points = [
    PricePoint(
      currency: SupportedCurrency.cad,
      fiatAmount: 100000,
      time: DateTime.utc(2026, 11, 2),
    ),
    PricePoint(
      currency: SupportedCurrency.cad,
      fiatAmount: 101000,
      time: DateTime.utc(2026, 11, 3),
    ),
  ];

  late Result<List<PricePoint>, PricerFailure> answer;
  late List<({BitcoinNetwork network, SupportedCurrency currency})> requests;
  late GetPriceHistoryUsecase usecase;

  setUp(() {
    answer = Ok(points);
    requests = [];
    usecase = GetPriceHistoryUsecase(
      getPriceHistory: ({required network, required currency}) async {
        requests.add((network: network, currency: currency));
        return answer;
      },
    );
  });

  test('gives the mainnet history of the currency', () async {
    final result = await usecase.execute(currencyCode: 'CAD');

    expect((result as Ok<List<PricePoint>, PriceChartFailure>).value, points);
    expect(requests.single, (
      network: BitcoinNetwork.mainnet,
      currency: SupportedCurrency.cad,
    ));
  });

  test('a history that cannot be loaded is a load failure', () async {
    answer = const Err(PricerNetworkFailure('offline'));

    final result = await usecase.execute(currencyCode: 'CAD');

    expect(
      (result as Err<List<PricePoint>, PriceChartFailure>).failure,
      isA<PriceChartLoadFailure>(),
    );
  });

  test('a currency without a price is unexpected, never asked', () async {
    final result = await usecase.execute(currencyCode: 'JPY');

    expect(
      (result as Err<List<PricePoint>, PriceChartFailure>).failure,
      isA<PriceChartUnexpectedFailure>(),
    );
    expect(requests, isEmpty);
  });
}
