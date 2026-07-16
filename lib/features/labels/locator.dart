import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/features/labels/adapters/labels_converter_apadater.dart';
import 'package:bb_mobile/features/labels/adapters/labels_repository_adapter.dart';
import 'package:bb_mobile/features/labels/adapters/wallet_freeze_adapter.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port.dart';
import 'package:bb_mobile/features/labels/application/labels_converter_port_registry.dart';
import 'package:bb_mobile/features/labels/application/labels_repository_port.dart';
import 'package:bb_mobile/features/labels/application/wallet_freeze_port.dart';
import 'package:bb_mobile/features/labels/application/usecases/store_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/trash_label_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_bip329_label_records_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/export_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_all_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/fetch_label_by_reference_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/import_labels_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/restore_bip329_label_records_usecase.dart';
import 'package:bb_mobile/features/labels/application/usecases/watch_label_changes_usecase.dart';
import 'package:bb_mobile/features/labels/domain/label_format.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/core/storage/storage.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:get_it/get_it.dart';

class LabelsLocator {
  static void registerPorts(GetIt locator) {
    locator.registerLazySingleton<LabelsRepositoryPort>(
      () => DriftLabelsRepositoryAdapter(database: locator<SqliteDatabase>()),
    );
    locator.registerLazySingleton<LabelsConverterPort>(
      () => LabelsConverterAdapter(locator<Bip329LabelsCodec>()),
    );
    locator.registerLazySingleton<LabelsConverterPortRegistry>(
      () => LabelsConverterPortRegistry({
        LabelFormat.bip329: locator<LabelsConverterPort>(),
      }),
    );
    locator.registerLazySingleton<WalletFreezePort>(
      () => WalletFreezeAdapter(locator<WalletUtxoRepository>()),
    );
  }

  static void registerFrameworks(GetIt locator) {
    locator.registerLazySingleton<Bip329LabelsCodec>(() => Bip329LabelsCodec());
  }

  static void registerUseCases(GetIt locator) {
    locator.registerFactory<TrashLabelUsecase>(
      () => TrashLabelUsecase(labelRepository: locator<LabelsRepositoryPort>()),
    );

    locator.registerFactory<ExportLabelsUsecase>(
      () => ExportLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
        converterRegistry: locator<LabelsConverterPortRegistry>(),
        walletFreeze: locator<WalletFreezePort>(),
      ),
    );

    locator.registerFactory<ImportLabelsUsecase>(
      () => ImportLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
        labelConverter: locator<LabelsConverterPort>(),
        walletFreeze: locator<WalletFreezePort>(),
      ),
    );

    locator.registerFactory<FetchAllLabelsUsecase>(
      () => FetchAllLabelsUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
      ),
    );

    locator.registerFactory<ExportBip329LabelRecordsUsecase>(
      () => ExportBip329LabelRecordsUsecase(
        fetchAllLabels: locator<FetchAllLabelsUsecase>(),
        converter: locator<LabelsConverterPort>(),
      ),
    );

    locator.registerFactory<RestoreBip329LabelRecordsUsecase>(
      () => RestoreBip329LabelRecordsUsecase(
        locator<LabelsRepositoryPort>(),
        locator<LabelsConverterPort>(),
      ),
    );

    locator.registerFactory<StoreLabelUsecase>(
      () => StoreLabelUsecase(labelRepository: locator<LabelsRepositoryPort>()),
    );

    locator.registerFactory<WatchLabelChangesUsecase>(
      () => WatchLabelChangesUsecase(locator<LabelsRepositoryPort>()),
    );

    locator.registerFactory<FetchLabelByReferenceUsecase>(
      () => FetchLabelByReferenceUsecase(
        labelRepository: locator<LabelsRepositoryPort>(),
      ),
    );
  }

  static void registerFacade(GetIt locator) {
    locator.registerLazySingleton<LabelsFacade>(
      () => LabelsFacade(
        fetchLabelByReferenceUsecase: locator<FetchLabelByReferenceUsecase>(),
        fetchAllLabelsUsecase: locator<FetchAllLabelsUsecase>(),
        storeLabelsUsecase: locator<StoreLabelUsecase>(),
        trashLabelUsecase: locator<TrashLabelUsecase>(),
        exportBip329LabelRecordsUsecase:
            locator<ExportBip329LabelRecordsUsecase>(),
        restoreBip329LabelRecordsUsecase:
            locator<RestoreBip329LabelRecordsUsecase>(),
        watchLabelChangesUsecase: locator<WatchLabelChangesUsecase>(),
      ),
    );
  }
}
