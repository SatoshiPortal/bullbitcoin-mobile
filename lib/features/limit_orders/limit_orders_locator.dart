import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/default_wallets/public/default_wallets_facade.dart';
import 'package:bb_mobile/features/limit_orders/data/datasources/limit_orders_api_datasource.dart';
import 'package:bb_mobile/features/limit_orders/data/limit_order_repository_impl.dart';
import 'package:bb_mobile/features/limit_orders/domain/repositories/limit_order_repository.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/can_create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_all_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/cancel_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/create_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/get_limit_order_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/list_active_limit_orders_usecase.dart';
import 'package:bb_mobile/features/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

final class LimitOrdersLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<LimitOrderRepository>(
      () => LimitOrderRepositoryImpl(
        LimitOrdersApiDatasource(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiClient',
          ),
        ),
        LimitOrdersApiDatasource(
          authenticatedApiClient: locator<Dio>(
            instanceName: 'authenticatedBullBitcoinApiTestClient',
          ),
        ),
        locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<ListActiveLimitOrdersUsecase>(
      () => ListActiveLimitOrdersUsecase(locator<LimitOrderRepository>()),
    );
    locator.registerFactory<CanCreateLimitOrderUsecase>(
      CanCreateLimitOrderUsecase.new,
    );
    locator.registerFactory<CancelAllLimitOrdersUsecase>(
      () => CancelAllLimitOrdersUsecase(locator<LimitOrderRepository>()),
    );
    locator.registerFactory<GetLimitOrderUsecase>(
      () => GetLimitOrderUsecase(locator<LimitOrderRepository>()),
    );
    locator.registerFactory<CancelLimitOrderUsecase>(
      () => CancelLimitOrderUsecase(locator<LimitOrderRepository>()),
    );
    locator.registerFactory<GetLimitOrderRateUsecase>(
      () => GetLimitOrderRateUsecase(locator<LimitOrderRepository>()),
    );
    locator.registerFactory<CreateLimitOrderUsecase>(
      () => CreateLimitOrderUsecase(
        locator<LimitOrderRepository>(),
        locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
    locator.registerFactory<LoadLimitOrderCreationUsecase>(
      () => LoadLimitOrderCreationUsecase(
        locator<GetExchangeUserSummaryUsecase>(),
        locator<DefaultWalletsFacade>(),
        locator<LimitOrderRepository>(),
      ),
    );

    locator.registerLazySingleton<LimitOrdersFacade>(
      () => LimitOrdersFacade(
        locator<ListActiveLimitOrdersUsecase>(),
        locator<CancelAllLimitOrdersUsecase>(),
        locator<CanCreateLimitOrderUsecase>(),
        locator<LoadLimitOrderCreationUsecase>(),
        locator<GetLimitOrderRateUsecase>(),
        locator<CreateLimitOrderUsecase>(),
        locator<GetLimitOrderUsecase>(),
        locator<CancelLimitOrderUsecase>(),
      ),
    );
  }
}
