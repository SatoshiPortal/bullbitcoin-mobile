import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_virtual_iban_details_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_from_viban_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:get_it/get_it.dart';

class WithdrawLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<CreateWithdrawOrderUsecase>(
      () => CreateWithdrawOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerLazySingleton<CreateWithdrawOrderFromVibanUsecase>(
      () => CreateWithdrawOrderFromVibanUsecase(
        mainnetVirtualIbanRepository: locator<VirtualIbanRepository>(
          instanceName: 'mainnetVirtualIbanRepository',
        ),
        testnetVirtualIbanRepository: locator<VirtualIbanRepository>(
          instanceName: 'testnetVirtualIbanRepository',
        ),
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ConfirmWithdrawOrderUsecase>(
      () => ConfirmWithdrawOrderUsecase(
        mainnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'mainnetExchangeOrderRepository',
        ),
        testnetExchangeOrderRepository: locator<ExchangeOrderRepository>(
          instanceName: 'testnetExchangeOrderRepository',
        ),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<WithdrawBloc>(
      () => WithdrawBloc(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
        getVirtualIbanDetailsUsecase: locator<GetVirtualIbanDetailsUsecase>(),
        createWithdrawUsecase: locator<CreateWithdrawOrderUsecase>(),
        createWithdrawOrderFromVibanUsecase:
            locator<CreateWithdrawOrderFromVibanUsecase>(),
        confirmWithdrawUsecase: locator<ConfirmWithdrawOrderUsecase>(),
      ),
    );
  }
}
