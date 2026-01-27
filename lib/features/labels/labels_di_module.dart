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
import 'package:bb_mobile/core/infra/di/feature_di_module.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

class LabelsDiModule implements FeatureDiModule {
  @override
  Future<void> registerFrameworksAndDrivers() async {
    sl.registerLazySingleton<Bip329LabelsCodec>(() => Bip329LabelsCodec());
  }

  @override
  Future<void> registerDrivenAdapters() async {
    sl.registerLazySingleton<LabelsRepositoryPort>(
      () => DriftLabelsRepositoryAdapter(database: sl<SqliteDatabase>()),
    );
    sl.registerLazySingleton<LabelsConverterPort>(
      () => LabelsConverterAdapter(sl<Bip329LabelsCodec>()),
    );
  }

  @override
  Future<void> registerApplicationServices() async {}

  @override
  Future<void> registerUseCases() async {
    sl.registerFactory<DeleteLabelUsecase>(
      () => DeleteLabelUsecase(labelRepository: sl()),
    );

    sl.registerFactory<ExportLabelsUsecase>(
      () => ExportLabelsUsecase(labelRepository: sl(), labelConverter: sl()),
    );

    sl.registerFactory<ImportLabelsUsecase>(
      () => ImportLabelsUsecase(labelRepository: sl(), labelConverter: sl()),
    );

    sl.registerFactory<FetchDistinctLabelsUsecase>(
      () => FetchDistinctLabelsUsecase(labelRepository: sl()),
    );

    sl.registerFactory<StoreLabelsUsecase>(
      () => StoreLabelsUsecase(labelRepository: sl()),
    );

    sl.registerFactory<FetchLabelByReferenceUsecase>(
      () => FetchLabelByReferenceUsecase(labelRepository: sl()),
    );
  }

  @override
  Future<void> registerDrivingAdapters() async {
    sl.registerLazySingleton<LabelsFacade>(
      () => LabelsFacade(
        fetchLabelByReferenceUsecase: sl(),
        fetchDistinctLabelsUsecase: sl(),
        storeLabelsUsecase: sl(),
        deleteLabelUsecase: sl(),
      ),
    );
  }
}
