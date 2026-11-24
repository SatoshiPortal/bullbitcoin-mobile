import 'package:backup_storage/backup_storage.dart';
import 'package:primitives/primitives.dart';

import 'data/backup_metadata_repository_impl.dart';
import 'data/backup_metadata_store.dart';
import 'domain/backup_metadata_failure.dart';
import 'domain/entities/backup_status.dart';
import 'domain/ports/backup_inventory_port.dart';
import 'domain/ports/backup_labels_port.dart';
import 'domain/ports/backup_readiness_port.dart';
import 'domain/repositories/backup_metadata_codec.dart';
import 'domain/usecases/run_backup_usecase.dart';

Future<Result<BackupRunStatus, BackupMetadataFailure>> runBackupMetadataTask({
  required BackupReadinessPort readiness,
  required BackupInventoryPort inventory,
  required BackupLabelsPort labels,
  required BackupMetadataCodec codec,
  required Iterable<BackupStorage> storages,
  required String statePath,
}) async {
  if (!await readiness.databaseReady()) {
    return const Err(BackupMetadataNotReadyFailure());
  }
  final repository = BackupMetadataRepositoryImpl(
    store: BackupMetadataStore(path: statePath),
    inventory: inventory,
    labels: labels,
    codec: codec,
    storages: storages,
  );
  return RunBackupUsecase(repository).execute();
}
