import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_address_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_transaction_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:get_it/get_it.dart';

class LabelsLocator {
  static void registerDatasources(GetIt locator) {
    locator.registerLazySingleton<LabelDatasource>(
      () => LabelDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories(GetIt locator) {
    locator.registerLazySingleton<LabelRepository>(
      () => LabelRepository(labelDatasource: locator<LabelDatasource>()),
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
  }
}
