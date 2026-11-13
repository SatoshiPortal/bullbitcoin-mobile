import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_key_fetch.dart';
import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';
import '../repositories/key_server_repository.dart';

/// Every counted request, including abandoned-backup cleanup, goes through
/// this durable gate. Manual key recovery uses RestoreVaultUsecase directly.
final class FetchVaultKeyUsecase {
  final AttemptMonitoringRepository _monitoring;

  const FetchVaultKeyUsecase(this._monitoring);

  Future<Result<VaultKeyFetch, RecoverBullFailure>> execute({
    required BackupSettings settings,
    required KeyServerRepository server,
    required EncryptedVault vault,
    required String password,
    bool trash = false,
  }) async {
    switch (await _monitoring.begin(settings, vault)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final result = trash
            ? await server.trash(vault, password)
            : await server.fetch(vault, password);
        final recorded = switch (result) {
          Ok(value: final fetched) => await _monitoring.complete(
            value,
            observation: fetched.observation,
            trashed: trash,
          ),
          Err(:final failure) => await _monitoring.complete(
            value,
            lockout:
                failure is KeyServerFailure &&
                failure.kind == KeyServerFailureKind.locked,
          ),
        };
        // Failed reconciliation leaves the marker intact. An obtained key or
        // completed deletion remains successful even if metadata is unavailable.
        switch (recorded) {
          case Ok():
          case Err():
            return result;
        }
    }
  }
}
