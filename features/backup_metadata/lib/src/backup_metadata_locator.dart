import 'package:backup_storage/backup_storage.dart';
import 'package:get_it/get_it.dart';

import 'data/backup_metadata_repository_impl.dart';
import 'data/backup_metadata_store.dart';
import 'domain/ports/backup_inventory_port.dart';
import 'domain/ports/backup_labels_port.dart';
import 'domain/repositories/backup_metadata_codec.dart';
import 'domain/usecases/apply_restore_usecase.dart';
import 'domain/usecases/configure_backup_usecase.dart';
import 'domain/usecases/discover_backups_usecase.dart';
import 'domain/usecases/get_backup_status_usecase.dart';
import 'domain/usecases/preview_restore_usecase.dart';
import 'domain/usecases/run_backup_usecase.dart';
import 'presentation/backup_metadata_restore_cubit.dart';
import 'presentation/backup_metadata_settings_cubit.dart';

abstract final class BackupMetadataLocator {
  static void setup({
    required GetIt locator,
    required String statePath,
    required BackupInventoryPort inventory,
    required BackupLabelsPort labels,
    required BackupMetadataCodec codec,
    required Iterable<BackupStorage> storages,
  }) {
    final repository = BackupMetadataRepositoryImpl(
      store: BackupMetadataStore(path: statePath),
      inventory: inventory,
      labels: labels,
      codec: codec,
      storages: storages,
    );
    locator
      ..registerSingleton(RunBackupUsecase(repository))
      ..registerSingleton(GetBackupStatusUsecase(repository))
      ..registerSingleton(ConfigureBackupUsecase(repository))
      ..registerSingleton(DiscoverBackupsUsecase(repository))
      ..registerSingleton(PreviewRestoreUsecase(labels))
      ..registerSingleton(ApplyRestoreUsecase(labels))
      ..registerFactory(
        () => BackupMetadataSettingsCubit(locator(), locator(), locator()),
      )
      ..registerFactory(
        () => BackupMetadataRestoreCubit(locator(), locator(), locator()),
      );
  }
}
