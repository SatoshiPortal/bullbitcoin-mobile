import 'package:bitcoin_price/src/domain/usecases/read_price_currency_usecase.dart';
import 'package:bitcoin_price/src/domain/bitcoin_price_failure.dart';
import 'package:bitcoin_price/src/domain/usecases/get_price_history_usecase.dart';
import 'package:bitcoin_price/src/presentation/cubit/price_chart_cubit.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetPriceHistory extends Mock implements GetPriceHistoryUsecase {}

class _MockGetSettings extends Mock implements ReadPriceCurrencyUsecase {}

PricePoint _point(int day) => PricePoint(
  currency: SupportedCurrency.cad,
  fiatAmount: 100000.0 + day,
  time: DateTime.utc(2026, 11, day),
);

void main() {
  late _MockGetPriceHistory history;
  late _MockGetSettings settings;
  late PriceChartCubit cubit;

  void answer(Result<List<PricePoint>, BitcoinPriceFailure> result) =>
      when(() => history.execute(currencyCode: any(named: 'currencyCode')))
          .thenAnswer((_) async => result);

  setUp(() {
    history = _MockGetPriceHistory();
    settings = _MockGetSettings();
    when(settings.execute).thenAnswer((_) async => const Ok('CAD'));
    cubit = PriceChartCubit(
      getPriceHistoryUsecase: history,
      readPriceCurrencyUsecase: settings,
    );
  });

  tearDown(() => cubit.close());

  test('shows the history in the settings currency', () async {
    answer(Ok([_point(2), _point(3)]));

    await cubit.loadPriceHistory();

    expect(cubit.state.prices, [_point(2), _point(3)]);
    expect(cubit.state.currency, 'CAD');
    expect(cubit.state.failure, isNull);
    expect(cubit.state.isLoading, isFalse);
    verify(() => history.execute(currencyCode: 'CAD')).called(1);
  });

  // The day history failed on the server and only the 15-minute point came
  // back: a single point is no chart.
  test('a single point is not shown as a chart', () async {
    answer(Ok([_point(4)]));

    await cubit.loadPriceHistory(currency: 'CAD');

    expect(cubit.state.prices, isEmpty);
    expect(cubit.state.failure, isA<PriceChartLoadFailure>());
  });

  test('a history that failed to load is a failure', () async {
    answer(const Err(PriceChartLoadFailure()));

    await cubit.loadPriceHistory(currency: 'CAD');

    expect(cubit.state.prices, isEmpty);
    expect(cubit.state.failure, isA<PriceChartLoadFailure>());
    expect(cubit.state.isLoading, isFalse);
  });

  test('a currency without a price is unexpected', () async {
    answer(const Err(BitcoinPriceUnexpectedFailure('JPY')));

    await cubit.loadPriceHistory(currency: 'JPY');

    expect(cubit.state.failure, isA<BitcoinPriceUnexpectedFailure>());
    expect(cubit.state.currency, 'JPY');
    expect(cubit.state.isLoading, isFalse);
  });

  test('opening the chart handles a failed preference read', () async {
    when(settings.execute)
        .thenAnswer((_) async => const Err(BitcoinPricePreferencesFailure()));

    await cubit.showChart();

    expect(cubit.state.showChart, isTrue);
    expect(cubit.state.failure, isA<BitcoinPricePreferencesFailure>());
    expect(cubit.state.isLoading, isFalse);
    verifyNever(
      () => history.execute(currencyCode: any(named: 'currencyCode')),
    );
  });
}
