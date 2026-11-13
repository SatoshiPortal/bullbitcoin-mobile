import 'package:bb_mobile/features/exchange_access/public/exchange_access_facade.dart';
import 'package:get_it/get_it.dart';

class ExchangeAccessLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<ExchangeAccessFacade>(
      ExchangeAccessFacade.new,
    );
  }
}
