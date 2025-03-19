import 'package:bb_mobile/_core/data/datasources/exchange_datasource.dart';
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
        exchange: locator<ExchangeDatasource>(
          instanceName: LocatorInstanceNameConstants
              .bullBitcoinExchangeDatasourceInstanceName,
        ),
      ),
    );

    // Usecases
    locator.registerFactory<GetAvailableFiatCurrenciesUsecase>(
      () => GetAvailableFiatCurrenciesUsecase(
        bitcoinPriceRepository: locator<BitcoinPriceRepository>(),
      ),
    );
    locator.registerFactory<FetchBitcoinPriceUsecase>(
      () => FetchBitcoinPriceUsecase(
        bitcoinPriceRepository: locator<BitcoinPriceRepository>(),
      ),
    );

    // Bloc
    locator.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        getAvailableFiatCurrenciesUsecase:
            locator<GetAvailableFiatCurrenciesUsecase>(),
        getCurrencyUsecase: locator<GetCurrencyUsecase>(),
        fetchBitcoinPriceUsecase: locator<FetchBitcoinPriceUsecase>(),
      ),
    );
  }
}
