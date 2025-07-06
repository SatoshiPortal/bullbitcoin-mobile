import 'dart:io';

import 'package:bb_mobile/features/template/data/datasources/local_datasource.dart';
import 'package:bb_mobile/features/template/data/datasources/remote_datasource.dart';
import 'package:bb_mobile/features/template/data/template_repository.dart';
import 'package:bb_mobile/features/template/domain/usecases/collect_and_cache_ip_usecase.dart';
import 'package:bb_mobile/features/template/domain/usecases/get_cached_ip_usecase.dart';
import 'package:bb_mobile/features/template/presentation/template_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TemplateFeatureLocator {
  static void setup() {
    locator.registerLazySingleton<RemoteDatasource>(() => RemoteDatasource());

    locator.registerLazySingleton<LocalDatasource>(
      () => LocalDatasource(directory: Directory.systemTemp),
    );

    locator.registerLazySingleton<TemplateRepository>(
      () => TemplateRepository(
        localDatasource: locator<LocalDatasource>(),
        remoteDatasource: locator<RemoteDatasource>(),
      ),
    );

    // Register use cases
    locator.registerFactory<CollectAndCacheIpUsecase>(
      () => CollectAndCacheIpUsecase(repository: locator<TemplateRepository>()),
    );

    locator.registerFactory<GetCachedIpUsecase>(
      () => GetCachedIpUsecase(repository: locator<TemplateRepository>()),
    );

    // Register cubit
    locator.registerFactory<TemplateCubit>(
      () => TemplateCubit(
        collectAndCacheIpUsecase: locator<CollectAndCacheIpUsecase>(),
        getCachedIpUsecase: locator<GetCachedIpUsecase>(),
      ),
    );
  }
}
