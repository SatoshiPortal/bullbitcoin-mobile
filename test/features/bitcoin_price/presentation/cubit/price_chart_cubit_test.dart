import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockGetPriceHistory extends Mock implements GetPriceHistoryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

PricePoint _point(int day) => PricePoint(
  currency: SupportedCurrency.cad,
  fiatAmount: 100000.0 + day,
  time: DateTime.utc(2026, 11, day),
);

void main() {
  late _MockGetPriceHistory history;
  late _MockGetSettings settings;
  late PriceChartCubit cubit;

  void answer(Result<List<PricePoint>, PriceChartFailure> result) => when(
    () => history.execute(currencyCode: any(named: 'currencyCode')),
  ).thenAnswer((_) async => result);

  setUp(() {
    history = _MockGetPriceHistory();
    settings = _MockGetSettings();
    when(settings.execute).thenAnswer(
      (_) async => SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
    cubit = PriceChartCubit(
      getPriceHistoryUsecase: history,
      getSettingsUsecase: settings,
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
    answer(const Err(PriceChartUnexpectedFailure('JPY')));

    await cubit.loadPriceHistory(currency: 'JPY');

    expect(cubit.state.failure, isA<PriceChartUnexpectedFailure>());
    expect(cubit.state.currency, 'JPY');
    expect(cubit.state.isLoading, isFalse);
  });

  test('a failed settings read is unexpected', () async {
    when(settings.execute).thenThrow(Exception('storage locked'));

    await cubit.loadPriceHistory();

    expect(cubit.state.failure, isA<PriceChartUnexpectedFailure>());
    expect(cubit.state.isLoading, isFalse);
    verifyNever(
      () => history.execute(currencyCode: any(named: 'currencyCode')),
    );
  });
}
