import 'dart:io';

import 'package:bb_mobile/features/template/data/datasources/local_datasource.dart';
import 'package:bb_mobile/features/template/data/datasources/remote_datasource.dart';
import 'package:bb_mobile/features/template/data/template_repository.dart';
import 'package:bb_mobile/features/template/domain/collect_ip_address_usecase.dart';
import 'package:bb_mobile/features/template/presentation/bloc/template_cubit.dart';
import 'package:bb_mobile/locator.dart';

class TemplateFeatureLocator {
  static void setup() {
    locator.registerLazySingleton<RemoteDatasource>(
      () => RemoteDatasource(httpClient: HttpClient()),
    );

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
    locator.registerFactory<CollectIpAddressUsecase>(
      () => CollectIpAddressUsecase(repository: locator<TemplateRepository>()),
    );

    // Register cubit
    locator.registerFactory<TemplateCubit>(
      () => TemplateCubit(usecase: locator<CollectIpAddressUsecase>()),
    );
  }
}
