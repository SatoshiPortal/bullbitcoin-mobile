import 'package:bb_mobile/features/bitcoin_price/domain/usecases/read_price_currency_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/watch_price_currency_usecase.dart';
import 'package:preferences/preferences.dart'
    show
        ActiveEnvironmentReader,
        AmountDisplayPreferencesReader,
        RuntimeDisplayPreferencesReader;
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/watch_bitcoin_price_amount_display_usecase.dart';

import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/features/bitcoin_price/public/bitcoin_price_facade.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';

class BitcoinPriceLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<BitcoinPriceFacade>(
      () => BitcoinPriceFacade(locator),
    );
    // Use cases
    locator.registerFactory<GetBitcoinPriceUsecase>(
      () => GetBitcoinPriceUsecase(
        environment: locator<ActiveEnvironmentReader>(),
        getIndexPrice: Pricer.getIndexPrice,
      ),
    );
    locator.registerFactory<GetPriceHistoryUsecase>(
      () =>
          const GetPriceHistoryUsecase(getPriceHistory: Pricer.getPriceHistory),
    );

    // Bloc
    locator.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        watchAmountDisplayUsecase: WatchBitcoinPriceAmountDisplayUsecase(
          locator<AmountDisplayPreferencesReader>(),
        ),
        readPriceCurrencyUsecase: ReadPriceCurrencyUsecase(
          locator<RuntimeDisplayPreferencesReader>(),
        ),
        getBitcoinPriceUsecase: locator<GetBitcoinPriceUsecase>(),
        watchPriceCurrencyUsecase: WatchPriceCurrencyUsecase(
          locator<RuntimeDisplayPreferencesReader>(),
        ),
      ),
    );

    // Cubit
    locator.registerFactory<PriceChartCubit>(
      () => PriceChartCubit(
        getPriceHistoryUsecase: locator<GetPriceHistoryUsecase>(),
        readPriceCurrencyUsecase: ReadPriceCurrencyUsecase(
          locator<RuntimeDisplayPreferencesReader>(),
        ),
      ),
    );
  }
}
