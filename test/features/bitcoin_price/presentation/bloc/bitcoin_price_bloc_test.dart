import 'dart:async';

import 'package:bb_mobile/core/price/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/price/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
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

  blocTest<BitcoinPriceBloc, BitcoinPriceState>(
    'a failed refresh keeps the last known price',
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
      expect(bloc.state.bitcoinPrice, 100000);
      expect(bloc.state.failure, isNotNull);
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
}
