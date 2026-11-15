import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/encrypted_vault.dart';
import '../entities/backup_settings.dart';
import '../entities/vault_completion.dart';
import '../entities/vault_context.dart';
import '../entities/vault_recovery.dart';
import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';
import '../repositories/backup_metadata_repository.dart';
import 'restore_vault_usecase.dart';
import 'test_vault_usecase.dart';

/// Manual-key inspection and recovery never depend on a server or database
/// opening successfully. Their completed effect and metadata warning differ.
final class CompleteVaultUsecase {
  final TestVaultUsecase _test;
  final RestoreVaultUsecase _restore;
  final BackupMetadataRepository? _metadata;
  final AttemptMonitoringRepository? _monitoring;
  final RecoverBullFailure? unavailableFailure;

  const CompleteVaultUsecase(
    this._test,
    this._restore,
    this._metadata,
    this._monitoring, {
    this.unavailableFailure,
  });

  Future<Result<VaultCompletion, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required VaultKey key,
    required BitcoinNetwork? recoveryNetwork,
    required bool Function() cancelled,
    BackupSettings? capturedSettings,
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    if (cancelled()) return const Err(VaultCancelledFailure());
    // A retained server key belongs to the settings under which it was fetched.
    // Re-check on every local passphrase attempt before reading or storing a seed.
    if (capturedSettings != null) {
      final metadata = _metadata;
      if (metadata == null) return const Err(VaultContextChangedFailure());
      switch (await metadata.settings()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          if (!value.permissionGranted ||
              value.server != capturedSettings.server ||
              value.generation != capturedSettings.generation) {
            return const Err(VaultContextChangedFailure());
          }
      }
      if (cancelled()) return const Err(VaultCancelledFailure());
    }
    final VaultContext? context;
    VaultRecovery? recovery;
    if (recoveryNetwork != null) {
      switch (await _restore.execute(
        vault: vault,
        key: key,
        network: recoveryNetwork,
        cancelled: cancelled,
        passphrase: passphrase,
        allowUnverified: allowUnverified,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          recovery = value;
          context = value is VaultRecovered && !allowUnverified
              ? value.context
              : null;
      }
    } else {
      switch (await _test.execute(
        vault: vault,
        key: key,
        passphrase: passphrase,
      )) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          context = value;
      }
    }
    // Successful test/import effects are accounted for even after UI close.
    final metadata = _metadata;
    final monitoring = _monitoring;
    if (metadata == null || monitoring == null) {
      return Ok(
        VaultCompletion(
          vault: vault,
          verifiedContext: context,
          recovery: recovery,
          warning: unavailableFailure ?? const RecoverBullJournalFailure(),
        ),
      );
    }
    RecoverBullFailure? warning;
    switch (capturedSettings == null
        ? await metadata.settings()
        : Ok<BackupSettings, RecoverBullFailure>(capturedSettings)) {
      case Err(:final failure):
        warning = failure;
      case Ok(:final value):
        if (await monitoring.register(value, vault) case Err(:final failure)) {
          warning = failure;
        }
    }
    if (context != null) {
      if (await metadata.markVerified(context, vault) case Err(
        :final failure,
      )) {
        warning ??= failure;
      }
    }
    return Ok(
      VaultCompletion(
        vault: vault,
        verifiedContext: context,
        recovery: recovery,
        warning: warning,
      ),
    );
  }
}
