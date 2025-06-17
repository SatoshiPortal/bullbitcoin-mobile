import 'package:bb_mobile/core/logging/data/log_datasource.dart';
import 'package:bb_mobile/core/logging/data/log_repository.dart';
import 'package:bb_mobile/core/logging/domain/add_log_usecase.dart';
import 'package:bb_mobile/locator.dart';

class LogLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<LogDatasource>(
      () => LocalFileLogDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<LogRepository>(
      () => LogRepository(logDatasource: locator<LogDatasource>()),
    );
  }

  static void registerUsecases() {
    locator.registerFactory<AddLogUsecase>(
      () => AddLogUsecase(logRepository: locator<LogRepository>()),
    );
  }
}
