import 'package:bb_mobile/core/data/datasources/exchange_data_source.dart';
import 'package:bb_mobile/core/data/datasources/key_value_storage_data_source.dart';
import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/fiat_currencies/data/repositories/fiat_currencies_repository.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/repositories/fiat_currencies_repository.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/fetch_bitcoin_price_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/get_available_fiat_currencies.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/get_fiat_currency_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/domain/usecases/set_fiat_currency_usecase.dart';
import 'package:bb_mobile/features/fiat_currencies/presentation/bloc/fiat_currencies_bloc.dart';

void setupFiatCurrenciesDependencies() {
  // Repositories
  locator.registerLazySingleton<FiatCurrenciesRepository>(
    () => FiatCurrenciesRepositoryImpl(
      exchange: locator<ExchangeDataSource>(
        instanceName: bullBitcoinExchangeInstanceName,
      ),
      storage: locator<KeyValueStorageDataSource<String>>(
        instanceName: settingsStorageInstanceName,
      ),
    ),
  );

  // Usecases
  locator.registerFactory<GetFiatCurrencyUseCase>(
    () => GetFiatCurrencyUseCase(
      fiatCurrenciesRepository: locator<FiatCurrenciesRepository>(),
    ),
  );
  locator.registerFactory<SetFiatCurrencyUseCase>(
    () => SetFiatCurrencyUseCase(
      fiatCurrenciesRepository: locator<FiatCurrenciesRepository>(),
    ),
  );
  locator.registerFactory<GetAvailableFiatCurrenciesUseCase>(
    () => GetAvailableFiatCurrenciesUseCase(
      fiatCurrenciesRepository: locator<FiatCurrenciesRepository>(),
    ),
  );
  locator.registerFactory<FetchBitcoinPriceUseCase>(
    () => FetchBitcoinPriceUseCase(
      fiatCurrenciesRepository: locator<FiatCurrenciesRepository>(),
    ),
  );

  // Bloc
  locator.registerFactory<FiatCurrenciesBloc>(
    () => FiatCurrenciesBloc(
      getAvailableFiatCurrenciesUseCase:
          locator<GetAvailableFiatCurrenciesUseCase>(),
      getFiatCurrencyUseCase: locator<GetFiatCurrencyUseCase>(),
      setFiatCurrencyUseCase: locator<SetFiatCurrencyUseCase>(),
      fetchBitcoinPriceUseCase: locator<FetchBitcoinPriceUseCase>(),
    ),
  );
}
