import 'package:bb_mobile/features/labels/data/label_repository.dart';
import 'package:bb_mobile/features/labels/domain/batch_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/features/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_address_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_transaction_usecase.dart';
import 'package:bb_mobile/features/labels/labels.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:get_it/get_it.dart';

class LabelsLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<LabelsLocalDatasource>(
      () => LabelsLocalDatasource(database: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<LabelRepository>(
      () => LabelRepository(labelDatasource: locator<LabelsLocalDatasource>()),
    );
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<LabelTransactionUsecase>(
      () =>
          LabelTransactionUsecase(labelRepository: locator<LabelRepository>()),
    );

    locator.registerFactory<LabelAddressUsecase>(
      () => LabelAddressUsecase(labelRepository: locator<LabelRepository>()),
    );

    locator.registerFactory<DeleteLabelUsecase>(
      () => DeleteLabelUsecase(labelRepository: locator<LabelRepository>()),
    );

    locator.registerFactory<ExportLabelsUsecase>(
      () => ExportLabelsUsecase(labelRepository: locator<LabelRepository>()),
    );

    locator.registerFactory<ImportLabelsUsecase>(
      () => ImportLabelsUsecase(labelRepository: locator<LabelRepository>()),
    );

    locator.registerFactory<FetchDistinctLabelsUsecase>(
      () => FetchDistinctLabelsUsecase(
        labelRepository: locator<LabelRepository>(),
      ),
    );
    locator.registerFactory<BatchLabelsUsecase>(
      () => BatchLabelsUsecase(labelRepository: locator<LabelRepository>()),
    );
  }
}
