/// Deterministic price scopes for widget tests of feature consumers.
library;

import 'package:bull_pricer/bull_pricer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'src/domain/usecases/get_bitcoin_price_usecase.dart';
import 'src/domain/usecases/get_price_history_usecase.dart';
import 'src/domain/usecases/read_price_currency_usecase.dart';
import 'src/domain/usecases/watch_price_currency_usecase.dart';
import 'src/presentation/bloc/bitcoin_price_bloc.dart';
import 'src/presentation/cubit/price_chart_cubit.dart';

abstract final class BitcoinPriceFixture {
  static BlocProvider<StateStreamableSource<Object?>> prices({
    AmountDisplayPreferences? amountDisplay,
    String? currency,
    double? bitcoinPrice,
    List<String>? availableCurrencies,
    bool loadingPrice = false,
  }) => BlocProvider<BitcoinPriceBloc>(
    create: (_) => _FixturePrices(
      BitcoinPriceState(
        amountDisplay: amountDisplay,
        currency: currency,
        bitcoinPrice: bitcoinPrice,
        availableCurrencies: availableCurrencies,
        loadingPrice: loadingPrice,
      ),
    ),
  );

  static BlocProvider<StateStreamableSource<Object?>> chart() =>
      BlocProvider<PriceChartCubit>(
        create: (_) => PriceChartCubit(
          getPriceHistoryUsecase: GetPriceHistoryUsecase(
            getPriceHistory: ({required network, required currency}) async =>
                const Err(PricerNetworkFailure()),
          ),
          readPriceCurrencyUsecase: const ReadPriceCurrencyUsecase(
            _FixturePreferences(),
          ),
        ),
      );
}

final class _FixturePrices extends BitcoinPriceBloc {
  _FixturePrices(BitcoinPriceState state)
    : super(
        readPriceCurrencyUsecase: const ReadPriceCurrencyUsecase(
          _FixturePreferences(),
        ),
        getBitcoinPriceUsecase: GetBitcoinPriceUsecase(
          environment: const _FixturePreferences(),
          getIndexPrice: ({required network, required currency}) async =>
              const Err(PricerNetworkFailure()),
        ),
        watchPriceCurrencyUsecase: const WatchPriceCurrencyUsecase(
          _FixturePreferences(),
        ),
        initialState: state,
      );

  @override
  void add(BitcoinPriceEvent event) {}
}

final class _FixturePreferences
    implements ActiveEnvironmentReader, RuntimeDisplayPreferencesReader {
  const _FixturePreferences();

  @override
  Stream<Result<String, PreferencesFailure>> get currencyChangeStream =>
      const Stream.empty();

  @override
  Future<Result<String, PreferencesFailure>> readCurrency() async =>
      const Ok('CAD');

  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => const Ok(Environment.mainnet);

  @override
  Future<Result<Language?, PreferencesFailure>> readLanguage() async =>
      const Ok(null);
}
