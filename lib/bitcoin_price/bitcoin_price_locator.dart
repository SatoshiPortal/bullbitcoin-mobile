import 'package:bb_mobile/_core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/_utils/constants.dart';
import 'package:bb_mobile/bitcoin_price/data/repositories/bitcoin_price_repository_impl.dart';
import 'package:bb_mobile/bitcoin_price/domain/repositories/bitcoin_price_repository.dart';
import 'package:bb_mobile/bitcoin_price/domain/usecases/fetch_bitcoin_price_usecase.dart';
import 'package:bb_mobile/bitcoin_price/domain/usecases/get_available_fiat_currencies.dart';
import 'package:bb_mobile/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BitcoinPriceLocator {
  static void setup() {
    // Repositories
    locator.registerLazySingleton<BitcoinPriceRepository>(
      () => BitcoinPriceRepositoryImpl(
        exchange: locator<ExchangeDataSource>(
          instanceName: LocatorInstanceNameConstants
              .bullBitcoinExchangeDataSourceInstanceName,
        ),
      ),
    );

    // Usecases
    locator.registerFactory<GetAvailableFiatCurrenciesUseCase>(
      () => GetAvailableFiatCurrenciesUseCase(
        bitcoinPriceRepository: locator<BitcoinPriceRepository>(),
      ),
    );
    locator.registerFactory<FetchBitcoinPriceUseCase>(
      () => FetchBitcoinPriceUseCase(
        bitcoinPriceRepository: locator<BitcoinPriceRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        getAvailableFiatCurrenciesUseCase:
            locator<GetAvailableFiatCurrenciesUseCase>(),
        getCurrencyUseCase: locator<GetCurrencyUseCase>(),
        fetchBitcoinPriceUseCase: locator<FetchBitcoinPriceUseCase>(),
      ),
    );
  }
}
