import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_all_intervals_rate_history_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_index_rate_history_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/watch_currency_changes_usecase.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/price_chart_bloc.dart';
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

    locator.registerFactory<PriceChartBloc>(
      () => PriceChartBloc(
        getIndexRateHistoryUsecase: locator<GetIndexRateHistoryUsecase>(),
        getAllIntervalsRateHistoryUsecase:
            locator<GetAllIntervalsRateHistoryUsecase>(),
        getSettingsUsecase: locator<GetSettingsUsecase>(),
      ),
    );
  }
}
