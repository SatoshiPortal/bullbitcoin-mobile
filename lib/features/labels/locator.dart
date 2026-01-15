import 'package:bb_mobile/features/labels/adapters/labels_converter_apadater.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/domain/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/delete_label_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/domain/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:get_it/get_it.dart';

class LabelsLocator {
  static void registerDatasources(GetIt locator) {
    // No datasources to register for labels feature
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<LabelsRepositoryPort>(
      () => DriftLabelsRepositoryAdapter(database: locator<SqliteDatabase>()),
    );

    locator.registerLazySingleton<Bip329LabelsCodec>(() => Bip329LabelsCodec());

    locator.registerLazySingleton<LabelsConverterPort>(
      () => LabelsConverterAdapter(locator<Bip329LabelsCodec>()),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<DeleteLabelUsecase>(
      () =>
          DeleteLabelUsecase(labelRepository: locator<LabelsRepositoryPort>()),
    );

    locator.registerFactory<ExportLabelsUsecase>(
      () => ExportLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
        labelConverter: locator<LabelsConverterPort>(),
      ),
    );

    locator.registerFactory<ImportLabelsUsecase>(
      () => ImportLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
        labelConverter: locator<LabelsConverterPort>(),
      ),
    );

    locator.registerFactory<FetchDistinctLabelsUsecase>(
      () => FetchDistinctLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
      ),
    );

    locator.registerFactory<StoreLabelsUsecase>(
      () =>
          StoreLabelsUsecase(labelRepository: locator<LabelsRepositoryPort>()),
    );

    locator.registerFactory<FetchLabelByReferenceUsecase>(
      () => FetchLabelByReferenceUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
      ),
    );

    locator.registerLazySingleton<LabelsFacade>(
      () => LabelsFacade(
        fetchLabelByReferenceUsecase: locator<FetchLabelByReferenceUsecase>(),
        fetchDistinctLabelsUsecase: locator<FetchDistinctLabelsUsecase>(),
        storeLabelsUsecase: locator<StoreLabelsUsecase>(),
        deleteLabelUsecase: locator<DeleteLabelUsecase>(),
      ),
    );
  }
}
