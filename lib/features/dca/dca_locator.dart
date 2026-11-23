import 'package:address_view/address_view.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:get_it/get_it.dart';

class DcaLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerFactory<StartDcaUsecase>(
      () => StartDcaUsecase(
        settingsRepository: locator<Preferences>(),
        exchange: locator<Exchange>(),
      ),
    );
    locator.registerFactory<SetDcaUsecase>(
      () => SetDcaUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        wallet: locator<WalletRepository>(),
        settingsRepository: locator<Preferences>(),
        walletAddressRepository: locator<AddressView>(),
        exchange: locator<Exchange>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<DcaBloc>(
      () => DcaBloc(
        startDcaUsecase: locator<StartDcaUsecase>(),
        setDcaUsecase: locator<SetDcaUsecase>(),
      ),
    );
  }
}
