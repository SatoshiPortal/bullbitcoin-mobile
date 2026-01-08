import 'package:bb_mobile/features/labels/data/label_local_datasource.dart';
import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/delete_label_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/core/storage/storage.dart';
import 'package:get_it/get_it.dart';

class LabelsLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<LabelsLocalDatasource>(
      () => LabelsLocalDatasource(locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<LabelsRepository>(
      () => LabelsRepository(labelDatasource: locator<LabelsLocalDatasource>()),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<DeleteLabelUsecase>(
      () => DeleteLabelUsecase(labelRepository: locator<LabelsRepository>()),
    );

    locator.registerFactory<ExportLabelsUsecase>(
      () => ExportLabelsUsecase(labelRepository: locator<LabelsRepository>()),
    );

    locator.registerFactory<ImportLabelsUsecase>(
      () => ImportLabelsUsecase(labelRepository: locator<LabelsRepository>()),
    );

    locator.registerFactory<FetchDistinctLabelsUsecase>(
      () => FetchDistinctLabelsUsecase(
        labelRepository: locator<LabelsRepository>(),
      ),
    );
    locator.registerFactory<StoreLabelsUsecase>(
      () => StoreLabelsUsecase(labelRepository: locator<LabelsRepository>()),
    );
  }
}
