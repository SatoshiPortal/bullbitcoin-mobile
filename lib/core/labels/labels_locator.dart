import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/data/label_storage_datasource.dart';
import 'package:bb_mobile/core/labels/domain/create_label_usecase.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/impl/shared_preferences_datasource_impl.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LabelsLocator {
  static Future<void> registerDatasources() async {
    locator.registerLazySingleton<LabelStorageDatasource>(
      () => LabelStorageDatasource(
        labelStorage: SharedPreferencesDatasourceImpl(SharedPreferencesAsync()),
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
