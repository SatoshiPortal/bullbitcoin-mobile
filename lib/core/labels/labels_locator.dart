import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/hive_storage_datasource_impl.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:hive/hive.dart';

class LabelsLocator {
  static Future<void> registerDatasources() async {
    final labelsBox = await Hive.openBox<String>(HiveBoxNameConstants.labels);
    final labelsByRefBox =
        await Hive.openBox<String>(HiveBoxNameConstants.labelsByRef);

    locator.registerLazySingleton<LabelStorageDatasource>(
      () => LabelStorageDatasource(
        mainLabelStorage: HiveStorageDatasourceImpl<String>(labelsBox),
        refLabelStorage: HiveStorageDatasourceImpl<String>(labelsByRefBox),
      ),
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
      () => CreateLabelUsecase(
        labelRepository: locator<LabelRepository>(),
        walletRepository: locator<WalletRepository>(),
      ),
    );
  }
}
