import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/locator.dart';

class LabelsLocator {
  static void registerDatasources() {
    locator.registerLazySingleton<LabelDatasource>(
      () => LabelDatasource(sqlite: locator<SqliteDatabase>()),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<LabelRepository>(
      () => LabelRepository(labelDatasource: locator<LabelDatasource>()),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<CreateLabelUsecase>(
      () => CreateLabelUsecase(labelRepository: locator<LabelRepository>()),
    );
  }
}
