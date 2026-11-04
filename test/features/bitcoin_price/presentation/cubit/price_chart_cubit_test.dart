import 'package:bb_mobile/core/price/domain/rate.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetPriceHistory extends Mock implements GetPriceHistoryUsecase {}

class _MockRefreshPriceHistory extends Mock
    implements RefreshPriceHistoryUsecase {}

class _MockGetSettings extends Mock implements GetSettingsUsecase {}

Rate _rate(RateTimelineInterval interval, int day) => Rate(
  fromCurrency: 'BTC',
  toCurrency: 'CAD',
  interval: interval,
  createdAt: DateTime.utc(2026, 11, day),
  indexPrice: 100000.0 + day,
);

void main() {
  late _MockGetPriceHistory stored;
  late _MockRefreshPriceHistory refreshed;
  late PriceChartCubit cubit;

  void answer(
    _MockGetPriceHistory? storedMock,
    _MockRefreshPriceHistory? refreshMock,
    RateTimelineInterval interval,
    List<Rate> rates,
  ) {
    if (storedMock != null) {
      when(
        () => storedMock.execute(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: interval,
        ),
      ).thenAnswer((_) async => rates);
    }
    if (refreshMock != null) {
      when(
        () => refreshMock.execute(
          fromCurrency: any(named: 'fromCurrency'),
          toCurrency: any(named: 'toCurrency'),
          interval: interval,
        ),
      ).thenAnswer((_) async => rates);
    }
  }

  setUp(() {
    stored = _MockGetPriceHistory();
    refreshed = _MockRefreshPriceHistory();
    final settings = _MockGetSettings();
    when(settings.execute).thenAnswer(
      (_) async => SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.btc,
        currencyCode: 'CAD',
      ),
    );
    cubit = PriceChartCubit(
      getPriceHistoryUsecase: stored,
      refreshPriceHistoryUsecase: refreshed,
      getSettingsUsecase: settings,
    );
    for (final interval in RateTimelineInterval.values) {
      answer(stored, refreshed, interval, []);
    }
  });

  tearDown(() => cubit.close());

  // The day history failed on the server and only the 15-minute point came
  // back: a single point is no chart.
  test('a single point is not shown as a chart', () async {
    answer(null, refreshed, RateTimelineInterval.fifteen, [
      _rate(RateTimelineInterval.fifteen, 4),
    ]);

    await cubit.loadPriceHistory(currency: 'CAD');

    expect(cubit.state.prices, isEmpty);
    expect(cubit.state.failure, isA<PriceChartLoadFailure>());
  });

  test('two points or more are shown', () async {
    answer(null, refreshed, RateTimelineInterval.day, [
      _rate(RateTimelineInterval.day, 2),
      _rate(RateTimelineInterval.day, 3),
    ]);

    await cubit.loadPriceHistory(currency: 'CAD');

    expect(cubit.state.prices, hasLength(2));
    expect(cubit.state.failure, isNull);
  });

  test('a stored chart stays when the refresh brings a single point', () async {
    answer(stored, null, RateTimelineInterval.day, [
      _rate(RateTimelineInterval.day, 2),
      _rate(RateTimelineInterval.day, 3),
    ]);
    answer(null, refreshed, RateTimelineInterval.fifteen, [
      _rate(RateTimelineInterval.fifteen, 4),
    ]);

    await cubit.loadPriceHistory(currency: 'CAD');

    expect(cubit.state.prices, hasLength(2));
    expect(cubit.state.failure, isNull);
  });
}
