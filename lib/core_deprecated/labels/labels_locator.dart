import 'package:bb_mobile/core_deprecated/labels/data/label_datasource.dart';
import 'package:bb_mobile/core_deprecated/labels/data/label_repository.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/delete_label_usecase.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/export_labels_usecase.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/fetch_distinct_labels_usecase.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/import_labels_usecase.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/label_wallet_address_usecase.dart';
import 'package:bb_mobile/core_deprecated/labels/domain/label_wallet_transaction_usecase.dart';
import 'package:bb_mobile/core/infra/database/sqlite_database.dart';
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
