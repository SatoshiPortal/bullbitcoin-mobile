import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_inventory.dart';

/// Groups the admitted inventory by its stored secret reference and
/// environment, and reports what cannot be backed up.
abstract interface class BackupInventoryPort {
  @useResult
  Future<Result<BackupInventory, BackupMetadataFailure>> read();
}
