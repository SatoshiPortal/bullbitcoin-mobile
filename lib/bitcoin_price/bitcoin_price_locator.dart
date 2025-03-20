import 'package:bb_mobile/_core/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_bitcoin_value_in_currency_usecase.dart';
import 'package:bb_mobile/_core/domain/usecases/get_currency_usecase.dart';
import 'package:bb_mobile/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/locator.dart';

class BitcoinPriceLocator {
  static void setup() {
    // Bloc
    locator.registerFactory<BitcoinPriceBloc>(
      () => BitcoinPriceBloc(
        getAvailableCurrenciesUsecase: locator<GetAvailableCurrenciesUsecase>(),
        getCurrencyUsecase: locator<GetCurrencyUsecase>(),
        getBitcoinValueInCurrencyUsecase:
            locator<GetBitcoinValueInCurrencyUsecase>(),
      ),
    );
  }
}
