import 'package:bull_logger/bull_logger.dart';
import 'package:get_it/get_it.dart';
import 'data/datasources/export_logs_datasource.dart';
import 'data/datasources/logger_logs_datasource.dart';
import 'data/datasources/share_logs_datasource.dart';
import 'data/logs_repository_impl.dart';
import 'domain/repositories/logs_repository.dart';
import 'domain/usecases/delete_logs_usecase.dart';
import 'domain/usecases/export_all_logs_usecase.dart';
import 'domain/usecases/export_logs_usecase.dart';
import 'domain/usecases/filter_logs_usecase.dart';
import 'domain/usecases/load_logs_usecase.dart';
import 'domain/usecases/share_all_logs_usecase.dart';
import 'domain/usecases/share_logs_usecase.dart';
import 'presentation/logs_cubit.dart';

final class LogsLocator {
  static void setup(GetIt locator) {
    locator.registerLazySingleton<LoggerLogsDatasource>(
      () => LoggerLogsDatasourceImpl(log),
    );
    locator.registerLazySingleton<ShareLogsDatasource>(
      SharePlusLogsDatasource.new,
    );
    locator.registerLazySingleton<ExportLogsDatasource>(
      FilePickerLogsDatasource.new,
    );
    locator.registerLazySingleton<LogsRepository>(
      () => LogsRepositoryImpl(locator(), locator(), locator()),
    );
    locator.registerFactory<LoadLogsUsecase>(() => LoadLogsUsecase(locator()));
    locator.registerFactory<DeleteLogsUsecase>(
      () => DeleteLogsUsecase(locator()),
    );
    locator.registerFactory<ShareLogsUsecase>(
      () => ShareLogsUsecase(locator()),
    );
    locator.registerFactory<ExportLogsUsecase>(
      () => ExportLogsUsecase(locator()),
    );
    locator.registerFactory<ShareAllLogsUsecase>(
      () => ShareAllLogsUsecase(locator()),
    );
    locator.registerFactory<ExportAllLogsUsecase>(
      () => ExportAllLogsUsecase(locator()),
    );
    locator.registerFactory<FilterLogsUsecase>(FilterLogsUsecase.new);
    locator.registerFactory<LogsCubit>(
      () => LogsCubit(locator(), locator(), locator(), locator(), locator()),
    );
  }
}
