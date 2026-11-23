import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../backup_metadata_failure.dart';
import '../entities/backup_inventory.dart';

/// Implemented by the wallet owner: groups wallets by stored secret identity,
/// never by fingerprint, and reports what cannot be backed up.
abstract interface class BackupInventoryPort {
  @useResult
  Future<Result<BackupInventory, BackupMetadataFailure>> read();
}
