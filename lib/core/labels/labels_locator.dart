import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/locator.dart';

class LabelsLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<LabelStorageDatasource>(
      () => LabelStorageDatasource(),
    );
  }

  static void registerRepositories() {
    locator.registerLazySingleton<LabelRepository>(
      () => LabelRepository(
        labelStorageDatasource: locator<LabelStorageDatasource>(),
      ),
    );
  }

  static void registerUseCases() {
    locator.registerFactory<CreateLabelUsecase>(
      () => CreateLabelUsecase(labelRepository: locator<LabelRepository>()),
    );
  }
}
