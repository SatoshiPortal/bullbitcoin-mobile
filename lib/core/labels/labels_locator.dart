import 'package:bb_mobile/core/labels/data/label_datasource.dart';
import 'package:bb_mobile/core/labels/data/label_repository.dart';
import 'package:bb_mobile/core/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_wallet_address_usecase.dart';
import 'package:bb_mobile/core/labels/domain/label_wallet_transaction_usecase.dart';
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
    locator.registerFactory<LabelWalletTransactionUsecase>(
      () => LabelWalletTransactionUsecase(
        labelRepository: locator<LabelRepository>(),
      ),
    );

    locator.registerFactory<LabelWalletAddressUsecase>(
      () => LabelWalletAddressUsecase(
        labelRepository: locator<LabelRepository>(),
      ),
    );

    locator.registerFactory<DeleteLabelUsecase>(
      () => DeleteLabelUsecase(labelRepository: locator<LabelRepository>()),
    );
  }
}
