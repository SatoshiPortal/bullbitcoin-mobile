import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:get_it/get_it.dart';

class BitcoinPriceLocator {
  static void setup(GetIt locator) {
    // Use cases
    locator.registerFactory<GetBitcoinPriceUsecase>(
      () => GetBitcoinPriceUsecase(
        getSettingsUsecase: locator<GetSettingsUsecase>(),
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
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        getBitcoinPriceUsecase: locator<GetBitcoinPriceUsecase>(),
        watchCurrencyChangesUsecase: locator<WatchCurrencyChangesUsecase>(),
      ),
    );

    // Cubit
    locator.registerFactory<PriceChartCubit>(
      () => PriceChartCubit(
        getPriceHistoryUsecase: locator<GetPriceHistoryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );
  }
}
