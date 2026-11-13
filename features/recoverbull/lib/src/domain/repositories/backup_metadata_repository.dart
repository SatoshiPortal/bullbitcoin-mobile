import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../entities/backup_status.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_context.dart';
import '../recoverbull_failure.dart';

abstract interface class BackupMetadataRepository {
  @useResult
  Future<Result<BackupSettings, RecoverBullFailure>> settings();

  @useResult
  Future<Result<void, RecoverBullFailure>> importLegacy(
    LegacyBackupSettings settings,
  );

  @useResult
  Future<Result<void, RecoverBullFailure>> changeServer(Uri server);

  /// Acceptance is for the displayed URL, not whatever URL is current later.
  @useResult
  Future<Result<void, RecoverBullFailure>> acceptServer(Uri displayedServer);

  @useResult
  Future<Result<void, RecoverBullFailure>> setMonitoring(bool enabled);

  @useResult
  Future<Result<BackupStatus, RecoverBullFailure>> status(VaultContext context);

  @useResult
  Future<Result<void, RecoverBullFailure>> markStored(
    VaultContext context,
    EncryptedVault vault,
  );

  @useResult
  Future<Result<void, RecoverBullFailure>> markVerified(
    VaultContext context,
    EncryptedVault vault,
  );
}
