import 'package:bb_mobile/core/dlc/data/datasources/dlc_api_datasource.dart';
import 'package:bb_mobile/core/dlc/data/repositories/dlc_repository_impl.dart';
import 'package:bb_mobile/core/dlc/domain/repositories/dlc_repository.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/cancel_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/check_dlc_connection_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_my_orders_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/get_orderbook_usecase.dart';
import 'package:bb_mobile/features/dlc/domain/usecases/place_dlc_order_usecase.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/connection/dlc_connection_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/my_orders/dlc_my_orders_cubit.dart';
import 'package:bb_mobile/features/dlc/presentation/bloc/orderbook/dlc_orderbook_cubit.dart';
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

/// Base URL of the external DLC engine REST API.
/// TODO: move to settings / environment config.
const _dlcEngineBaseUrl = 'https://dlc-engine.example.com/api/v1';

class DlcLocator {
  static void setup(GetIt locator) {
    _registerDatasources(locator);
    _registerRepositories(locator);
    _registerUsecases(locator);
    _registerBlocs(locator);
  }

  static void _registerDatasources(GetIt locator) {
    locator.registerLazySingleton<DlcApiDatasource>(
      () => DlcApiDatasource(
        dio: locator<Dio>(),
        baseUrl: _dlcEngineBaseUrl,
      ),
    );
  }

  static void _registerRepositories(GetIt locator) {
    locator.registerLazySingleton<DlcRepository>(
      () => DlcRepositoryImpl(
        datasource: locator<DlcApiDatasource>(),
      ),
    );
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<CheckDlcConnectionUsecase>(
      () => CheckDlcConnectionUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetOrderbookUsecase>(
      () => GetOrderbookUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<GetMyOrdersUsecase>(
      () => GetMyOrdersUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<PlaceDlcOrderUsecase>(
      () => PlaceDlcOrderUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
    locator.registerFactory<CancelDlcOrderUsecase>(
      () => CancelDlcOrderUsecase(
        dlcRepository: locator<DlcRepository>(),
      ),
    );
  }

  static void _registerBlocs(GetIt locator) {
    locator.registerFactory<DlcConnectionCubit>(
      () => DlcConnectionCubit(
        checkDlcConnectionUsecase: locator<CheckDlcConnectionUsecase>(),
      ),
    );
    locator.registerFactory<DlcOrderbookCubit>(
      () => DlcOrderbookCubit(
        getOrderbookUsecase: locator<GetOrderbookUsecase>(),
      ),
    );
    locator.registerFactory<DlcMyOrdersCubit>(
      () => DlcMyOrdersCubit(
        getMyOrdersUsecase: locator<GetMyOrdersUsecase>(),
        cancelDlcOrderUsecase: locator<CancelDlcOrderUsecase>(),
      ),
    );
  }
}
