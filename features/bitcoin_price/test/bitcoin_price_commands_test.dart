import 'dart:async';

import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:bull_ui/bull_ui.dart' show BuildContext, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

class _Preferences extends Mock
    implements
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader {}

Future<BuildContext> _mount(
  WidgetTester tester, {
  IndexPriceReader? getIndexPrice,
  PriceHistoryReader? getPriceHistory,
}) async {
  final preferences = _Preferences();
  when(preferences.readActiveEnvironment)
      .thenAnswer((_) async => const Ok(Environment.mainnet));
  when(preferences.readCurrency).thenAnswer((_) async => const Ok('CAD'));
  when(() => preferences.currencyChangeStream)
      .thenAnswer((_) => const Stream.empty());
  when(preferences.watchDisplayPreferences)
      .thenAnswer((_) => const Stream.empty());
  final feature = BitcoinPriceFeature.mount(
    environment: preferences,
    amountDisplay: preferences,
    display: preferences,
    getIndexPrice: getIndexPrice,
    getPriceHistory: getPriceHistory,
  );
  await tester.pumpWidget(
    feature.providePrices(
      child: feature.provideEmbeddedChart(child: const SizedBox.shrink()),
    ),
  );
  return tester.element(find.byType(SizedBox));
}

BitcoinPrice _price(SupportedCurrency currency) => BitcoinPrice(
  currency: currency,
  fiatAmount: 100000,
  fetchedAt: DateTime.utc(2026),
);

void main() {
  testWidgets('refresh shares the startup result and can recover', (
    tester,
  ) async {
    final startup = Completer<Result<BitcoinPrice, PricerFailure>>();
    var requests = 0;
    final context = await _mount(
      tester,
      getIndexPrice: ({required network, required currency}) {
        return ++requests == 1
            ? startup.future
            : Future.value(Ok(_price(currency)));
      },
    );
    final Future<Result<void, BitcoinPriceFailure>> refresh =
        BitcoinPriceFeature.refresh(context, onlyIfUnavailable: true);
    var finished = false;
    unawaited(refresh.then((_) => finished = true));
    await tester.pump();
    expect(requests, 1);
    expect(finished, isFalse);

    startup.complete(const Err(PricerNetworkFailure()));
    await tester.pump();
    expect(
      await refresh,
      isA<Err<void, BitcoinPriceFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<BitcoinPriceNetworkFailure>(),
      ),
    );

    final retry = BitcoinPriceFeature.refresh(context);
    await tester.pump();
    expect(await retry, isA<Ok<void, BitcoinPriceFailure>>());
    final skip = BitcoinPriceFeature.refresh(context, onlyIfUnavailable: true);
    await tester.pump();
    expect(await skip, isA<Ok<void, BitcoinPriceFailure>>());
    expect(requests, 2);
  });

  testWidgets(
    'currency commands share the actual quote and return its failure',
    (tester) async {
      final usdQuote = Completer<Result<BitcoinPrice, PricerFailure>>();
      final requests = <SupportedCurrency>[];
      final context = await _mount(
        tester,
        getIndexPrice: ({required network, required currency}) {
          requests.add(currency);
          return switch (currency) {
            SupportedCurrency.usd => usdQuote.future,
            SupportedCurrency.eur => Future.value(
              const Err(PricerRateLimitedFailure()),
            ),
            _ => Future.value(Ok(_price(currency))),
          };
        },
      );
      final Future<Result<void, BitcoinPriceFailure>> quote =
          BitcoinPriceFeature.quoteInCurrency(context, 'USD');
      final duplicate = BitcoinPriceFeature.quoteInCurrency(context, 'USD');
      var finished = false;
      unawaited(duplicate.then((_) => finished = true));
      await tester.pump();
      expect(
        requests.where((currency) => currency == SupportedCurrency.usd),
        hasLength(1),
      );
      expect(finished, isFalse);

      usdQuote.complete(Ok(_price(SupportedCurrency.usd)));
      await tester.pump();
      expect(await quote, isA<Ok<void, BitcoinPriceFailure>>());
      expect(await duplicate, isA<Ok<void, BitcoinPriceFailure>>());

      final failed = BitcoinPriceFeature.quoteInCurrency(context, 'EUR');
      await tester.pump();
      expect(
        await failed,
        isA<Err<void, BitcoinPriceFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<BitcoinPriceRateUnavailableFailure>(),
        ),
      );
    },
  );

  testWidgets('showChart returns the result of loading usable history', (
    tester,
  ) async {
    final pending = Completer<Result<List<PricePoint>, PricerFailure>>();
    var requests = 0;
    List<PricePoint> points(int count) => List.generate(
      count,
      (index) => PricePoint(
        currency: SupportedCurrency.cad,
        fiatAmount: 100000.0 + index,
        time: DateTime.utc(2026, 11, index + 1),
      ),
    );
    final context = await _mount(
      tester,
      getPriceHistory: ({required network, required currency}) {
        return ++requests == 1 ? pending.future : Future.value(Ok(points(1)));
      },
    );
    final Future<Result<void, BitcoinPriceFailure>> show =
        BitcoinPriceFeature.showChart(context);
    var finished = false;
    unawaited(show.then((_) => finished = true));
    await tester.pump();
    expect(requests, 1);
    expect(finished, isFalse);

    pending.complete(Ok(points(2)));
    await tester.pump();
    expect(await show, isA<Ok<void, BitcoinPriceFailure>>());

    final incomplete = BitcoinPriceFeature.showChart(context);
    await tester.pump();
    expect(
      await incomplete,
      isA<Err<void, BitcoinPriceFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<PriceChartLoadFailure>(),
      ),
    );
  });
}
