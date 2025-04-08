import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_repository.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:dio/dio.dart';

class FeesLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<FeesDatasource>(
      () => FeesDatasource(
        http: Dio(),
      ),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<FeesRepository>(
      () => FeesRepository(
        feesDatasource: locator<FeesDatasource>(),
      ),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<GetNetworkFeesUsecase>(
      () => GetNetworkFeesUsecase(
        feesRepository: locator<FeesRepository>(),
      ),
    );
  }
}
