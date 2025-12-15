import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_price_history_usecase.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/refresh_price_history_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/cubit/price_chart_cubit.dart';
import 'package:bb_mobile/locator.dart';

class BitcoinPriceLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        watchCurrencyChangesUsecase: locator<WatchCurrencyChangesUsecase>(),
      ),
    );

    // Cubit
    locator.registerFactory<PriceChartCubit>(
      () => PriceChartCubit(
        getPriceHistoryUsecase: locator<GetPriceHistoryUsecase>(),
        refreshPriceHistoryUsecase: locator<RefreshPriceHistoryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );
  }
}
