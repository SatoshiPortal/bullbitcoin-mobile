import 'dart:async';

import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/bitcoin_price_failure.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetAvailableCurrenciesUsecase extends Mock
    implements GetAvailableCurrenciesUsecase {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockConvertSatsToCurrencyAmountUsecase extends Mock
    implements ConvertSatsToCurrencyAmountUsecase {}

class _MockWatchCurrencyChangesUsecase extends Mock
    implements WatchCurrencyChangesUsecase {}

void main() {
  const currencies = ['USD', 'CAD'];

  late _MockGetAvailableCurrenciesUsecase getAvailableCurrencies;
  late _MockGetSettingsUsecase getSettings;
  late _MockConvertSatsToCurrencyAmountUsecase convertSatsToCurrency;
  late _MockWatchCurrencyChangesUsecase watchCurrencyChanges;

  BitcoinPriceBloc buildBloc() => BitcoinPriceBloc(
    getAvailableCurrenciesUsecase: getAvailableCurrencies,
    getSettingsUsecase: getSettings,
    convertSatsToCurrencyAmountUsecase: convertSatsToCurrency,
    watchCurrencyChangesUsecase: watchCurrencyChanges,
  );

  void stubPrice(Future<double> Function() answer) {
    when(
      () => convertSatsToCurrency.execute(currencyCode: 'USD'),
    ).thenAnswer((_) => answer());
  }

  setUp(() {
    getAvailableCurrencies = _MockGetAvailableCurrenciesUsecase();
    getSettings = _MockGetSettingsUsecase();
    convertSatsToCurrency = _MockConvertSatsToCurrencyAmountUsecase();
    watchCurrencyChanges = _MockWatchCurrencyChangesUsecase();

    when(
      () => watchCurrencyChanges.execute(),
    ).thenAnswer((_) => const Stream.empty());
    when(() => getSettings.execute()).thenAnswer(
      (_) async => SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => getAvailableCurrencies.execute(),
    ).thenAnswer((_) async => currencies);
  });

  group('offline start', () {
    // The price datasource maps a network error to a zero rate.
    blocTest<BitcoinPriceBloc, BitcoinPriceState>(
      'keeps the currency and its list when the price fails',
      build: () {
        stubPrice(() async => 0);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BitcoinPriceStarted()),
      verify: (bloc) {
        expect(bloc.state.currency, 'USD');
        expect(bloc.state.availableCurrencies, currencies);
        expect(bloc.state.hasValidFiatRate, isFalse);
        expect(bloc.state.startupFailed, isTrue);
        expect(bloc.state.loadingPrice, isFalse);
      },
    );

    blocTest<BitcoinPriceBloc, BitcoinPriceState>(
      'keeps the currency and its list when the price throws',
      build: () {
        stubPrice(() async => throw Exception('offline'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const BitcoinPriceStarted()),
      verify: (bloc) {
        expect(bloc.state.currency, 'USD');
        expect(bloc.state.availableCurrencies, currencies);
        expect(bloc.state.hasValidFiatRate, isFalse);
        expect(bloc.state.startupFailed, isTrue);
      },
    );

    var online = false;

    blocTest<BitcoinPriceBloc, BitcoinPriceState>(
      'recovers the price on a refresh once back online',
      build: () {
        online = false;
        stubPrice(() async => online ? 100000 : 0);
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const BitcoinPriceStarted());
        await bloc.stream.firstWhere((s) => s.startupFailed);
        online = true;
        bloc.add(const BitcoinPriceFetched());
      },
      verify: (bloc) {
        expect(bloc.state.bitcoinPrice, 100000);
        expect(bloc.state.hasValidFiatRate, isTrue);
        expect(bloc.state.startupFailed, isFalse);
        expect(bloc.state.failure, isNull);
      },
    );
  });

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a refresh before anything loaded loads the currency, list and price',
    build: () {
      stubPrice(() async => 100000);
      return buildBloc();
    },
    act: (bloc) => bloc.add(const BitcoinPriceFetched()),
    verify: (bloc) {
      expect(bloc.state.currency, 'USD');
      expect(bloc.state.availableCurrencies, currencies);
      expect(bloc.state.bitcoinPrice, 100000);
    },
  );

  // A refresh only reaches the pricer once the repository's price is over a
  // minute old, so the price still on screen is outdated: with no answer,
  // show no price rather than that one.
  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a failed refresh drops the outdated price',
    build: () {
      var online = true;
      stubPrice(() async {
        if (online) {
          online = false;
          return 100000;
        }
        throw Exception('offline');
      });
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const BitcoinPriceStarted());
      await bloc.stream.firstWhere((s) => s.hasValidFiatRate);
      bloc.add(const BitcoinPriceFetched());
    },
    verify: (bloc) {
      expect(bloc.state.bitcoinPrice, isNull);
      expect(bloc.state.hasValidFiatRate, isFalse);
      expect(bloc.state.currency, 'USD');
      expect(bloc.state.failure, isNotNull);
    },
  );

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a refresh answered with no rate drops the outdated price',
    build: () {
      var online = true;
      stubPrice(() async {
        if (online) {
          online = false;
          return 100000;
        }
        // The datasource reports an unreachable pricer as a zero rate.
        return 0;
      });
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const BitcoinPriceStarted());
      await bloc.stream.firstWhere((s) => s.hasValidFiatRate);
      bloc.add(const BitcoinPriceFetched());
    },
    verify: (bloc) {
      expect(bloc.state.bitcoinPrice, isNull);
      expect(bloc.state.hasValidFiatRate, isFalse);
      expect(bloc.state.failure, isA<BitcoinPriceInvalidRateFailure>());
    },
  );

  // Created in `build`, inside the test's zone: an error completed from
  // outside it would never reach the bloc's catch.
  late Completer<double> slowUsdRefresh;

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a refresh that lands after a currency change does not overwrite it',
    build: () {
      slowUsdRefresh = Completer<double>();
      var usdCalls = 0;
      stubPrice(() {
        usdCalls++;
        // The start-up fetch answers at once; the refresh hangs until the
        // test releases it, after the currency has changed.
        return usdCalls == 1 ? Future.value(100000) : slowUsdRefresh.future;
      });
      when(
        () => convertSatsToCurrency.execute(currencyCode: 'EUR'),
      ).thenAnswer((_) async => 90000);
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const BitcoinPriceStarted());
      await bloc.stream.firstWhere((s) => s.hasValidFiatRate);
      bloc.add(const BitcoinPriceFetched());
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'EUR'));
      await bloc.stream.firstWhere(
        (s) => s.currency == 'EUR' && s.bitcoinPrice == 90000,
      );
      slowUsdRefresh.complete(100000);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      expect(bloc.state.currency, 'EUR');
      expect(bloc.state.bitcoinPrice, 90000);
    },
  );

  late Completer<double> slowUsdStart;

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a start-up price that lands after a currency change does not overwrite it',
    build: () {
      slowUsdStart = Completer<double>();
      stubPrice(() => slowUsdStart.future);
      when(
        () => convertSatsToCurrency.execute(currencyCode: 'EUR'),
      ).thenAnswer((_) async => 90000);
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const BitcoinPriceStarted());
      await bloc.stream.firstWhere((s) => s.availableCurrencies != null);
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'EUR'));
      await bloc.stream.firstWhere(
        (s) => s.currency == 'EUR' && s.bitcoinPrice == 90000,
      );
      slowUsdStart.complete(100000);
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      expect(bloc.state.currency, 'EUR');
      expect(bloc.state.bitcoinPrice, 90000);
    },
  );

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a second pull while the first load runs does not start another',
    build: () {
      stubPrice(() async => 100000);
      return buildBloc();
    },
    act: (bloc) async {
      bloc
        ..add(const BitcoinPriceFetched())
        ..add(const BitcoinPriceFetched());
      await bloc.stream.firstWhere((s) => s.hasValidFiatRate);
    },
    verify: (bloc) {
      verify(() => getSettings.execute()).called(1);
      verify(
        () => convertSatsToCurrency.execute(currencyCode: 'USD'),
      ).called(1);
    },
  );

  late Completer<double> failingUsdRefresh;

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a refresh that fails after a currency change does not flag the new one',
    build: () {
      failingUsdRefresh = Completer<double>();
      var usdCalls = 0;
      stubPrice(() {
        usdCalls++;
        return usdCalls == 1 ? Future.value(100000) : failingUsdRefresh.future;
      });
      when(
        () => convertSatsToCurrency.execute(currencyCode: 'EUR'),
      ).thenAnswer((_) async => 90000);
      return buildBloc();
    },
    act: (bloc) async {
      bloc.add(const BitcoinPriceStarted());
      await bloc.stream.firstWhere((s) => s.hasValidFiatRate);
      bloc.add(const BitcoinPriceFetched());
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'EUR'));
      await bloc.stream.firstWhere(
        (s) => s.currency == 'EUR' && s.bitcoinPrice == 90000,
      );
      failingUsdRefresh.completeError(Exception('offline'));
      await Future<void>.delayed(Duration.zero);
    },
    verify: (bloc) {
      expect(bloc.state.currency, 'EUR');
      expect(bloc.state.bitcoinPrice, 90000);
      expect(bloc.state.failure, isNull);
    },
  );

  group('currency change bursts', () {
    // A screen rebuilding on every frame of a keyboard or route animation used
    // to send the flow's currency once per frame: eight pricer calls in 0.65 s
    // measured on a Pixel 6a when the sell wallet selection opened.
    Future<void> burst(BitcoinPriceBloc bloc, String currency) async {
      for (var i = 0; i < 8; i++) {
        bloc.add(BitcoinPriceCurrencyChanged(currencyCode: currency));
      }
      await pumpEventQueue();
    }

    test('a burst towards the loaded currency reads it once', () async {
      // Re-reading the shown currency is allowed: the price repository serves
      // it from its minute-long cache, so the pricer is not asked again.
      final answer = Completer<double>();
      stubPrice(() async => 70000);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const BitcoinPriceStarted());
      await pumpEventQueue();
      clearInteractions(convertSatsToCurrency);
      stubPrice(() => answer.future);

      await burst(bloc, 'USD');
      answer.complete(71000);
      await pumpEventQueue();

      verify(
        () => convertSatsToCurrency.execute(currencyCode: 'USD'),
      ).called(1);
      expect(bloc.state.bitcoinPrice, 71000);
    });

    test('an answer for a currency left since does not overwrite', () async {
      final usd = Completer<double>();
      stubPrice(() => usd.future);
      when(
        () => convertSatsToCurrency.execute(currencyCode: 'CAD'),
      ).thenAnswer((_) async => 95000);
      final bloc = buildBloc();
      addTearDown(bloc.close);

      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'USD'));
      await pumpEventQueue();
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'CAD'));
      await pumpEventQueue();
      usd.complete(70000);
      await pumpEventQueue();

      expect(bloc.state.currency, 'CAD');
      expect(bloc.state.bitcoinPrice, 95000);
    });

    test('a burst towards a new currency fetches it once', () async {
      final answer = Completer<double>();
      stubPrice(() => answer.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);

      await burst(bloc, 'USD');
      answer.complete(70000);
      await pumpEventQueue();

      verify(
        () => convertSatsToCurrency.execute(currencyCode: 'USD'),
      ).called(1);
      expect(bloc.state.currency, 'USD');
      expect(bloc.state.bitcoinPrice, 70000);
    });

    test('a currency whose fetch failed is fetched again', () async {
      stubPrice(() async => 0);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'USD'));
      await pumpEventQueue();
      expect(bloc.state.hasValidFiatRate, isFalse);

      stubPrice(() async => 70000);
      bloc.add(const BitcoinPriceCurrencyChanged(currencyCode: 'USD'));
      await pumpEventQueue();

      verify(
        () => convertSatsToCurrency.execute(currencyCode: 'USD'),
      ).called(2);
      expect(bloc.state.bitcoinPrice, 70000);
    });

    test('switching to another currency still fetches it', () async {
      final cad = Completer<double>();
      stubPrice(() async => 70000);
      when(
        () => convertSatsToCurrency.execute(currencyCode: 'CAD'),
      ).thenAnswer((_) => cad.future);
      final bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const BitcoinPriceStarted());
      await pumpEventQueue();

      await burst(bloc, 'CAD');
      cad.complete(95000);
      await pumpEventQueue();

      verify(
        () => convertSatsToCurrency.execute(currencyCode: 'CAD'),
      ).called(1);
      expect(bloc.state.currency, 'CAD');
      expect(bloc.state.bitcoinPrice, 95000);
    });
  });
}
