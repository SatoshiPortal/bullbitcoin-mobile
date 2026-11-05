import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/address_view/public/address_view_facade.dart';
import 'package:wallet/wallet.dart';
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
        settingsRepository: locator<SettingsRepository>(),
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
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
        settingsRepository: locator<SettingsRepository>(),
        walletAddressRepository: locator<LabeledWalletAddressRepository>(),
        mainnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'mainnetExchangeUserRepository',
        ),
        testnetExchangeUserRepository: locator<ExchangeUserRepository>(
          instanceName: 'testnetExchangeUserRepository',
        ),
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
