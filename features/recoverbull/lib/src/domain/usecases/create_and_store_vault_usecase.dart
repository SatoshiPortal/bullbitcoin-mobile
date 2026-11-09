import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_completion.dart';
import '../entities/vault_context.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../repositories/attempt_monitoring_repository.dart';
import '../repositories/backup_metadata_repository.dart';
import '../repositories/key_server_repository.dart';
import 'create_vault_usecase.dart';
import 'fetch_vault_key_usecase.dart';
import 'save_vault_usecase.dart';

/// One flow owns this instance. Retry keeps only the encrypted file, never its
/// password or key. The session owner waits for execute before closing it.
final class CreateAndStoreVaultUsecase {
  final CreateVaultUsecase _create;
  final SaveVaultUsecase _save;
  final BackupMetadataRepository _metadata;
  final AttemptMonitoringRepository _monitoring;
  final FetchVaultKeyUsecase _fetch;
  ({EncryptedVault vault, VaultContext context, Uri server})? _pending;
  bool _closed = false;
  bool _busy = false;

  CreateAndStoreVaultUsecase(
    this._create,
    this._save,
    this._metadata,
    this._monitoring,
    this._fetch,
  );

  bool get hasPendingProviderSave => _pending != null;

  void close() {
    _closed = true;
    _pending = null;
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> execute({
    required BackupSettings settings,
    required KeyServerRepository server,
    required VaultProvider provider,
    required String password,
  }) async {
    if (_closed) return const Err(VaultCancelledFailure());
    if (_busy || hasPendingProviderSave) {
      return const Err(VaultContextChangedFailure());
    }
    _busy = true;
    try {
      final ({EncryptedVault vault, VaultContext context, Uri server}) pending;
      final created = await _create.execute();
      if (_closed) return const Err(VaultCancelledFailure());
      switch (created) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          // Register all created vaults, independently of certification.
          switch (await _monitoring.register(settings, value.vault)) {
            case Err(:final failure):
              return Err(failure);
            case Ok():
              break;
          }
          if (_closed) return const Err(VaultCancelledFailure());
          switch (await _metadata.settings()) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: final current):
              if (!current.permissionGranted ||
                  current.server != settings.server ||
                  current.generation != settings.generation) {
                return const Err(VaultContextChangedFailure());
              }
          }
          if (_closed) return const Err(VaultCancelledFailure());
          switch (await server.store(value.vault, password, value.key)) {
            case Err(:final failure):
              return Err(failure);
            case Ok():
              break;
          }
          if (_closed) {
            // No provider was invoked. Cleanup is counted and must pass the
            // same durable admission gate as a user-initiated fetch.
            final cleanup = await _fetch.execute(
              settings: settings,
              server: server,
              vault: value.vault,
              password: password,
              trash: true,
            );
            if (cleanup is Err) {
              log.warning('recoverbull.abandoned.cleanup.failed');
            }
            return const Err(VaultCancelledFailure());
          }
          pending = (
            vault: value.vault,
            context: value.context,
            server: settings.server,
          );
          _pending = pending;
      }
      return await _savePending(pending, provider);
    } finally {
      _busy = false;
    }
  }

  /// Retries only the provider write; the original server password stays valid.
  Future<Result<VaultCompletion, RecoverBullFailure>> retryProviderSave(
    VaultProvider provider,
  ) async {
    if (_closed) return const Err(VaultCancelledFailure());
    final pending = _pending;
    if (_busy || pending == null) {
      return const Err(VaultContextChangedFailure());
    }
    _busy = true;
    try {
      return await _savePending(pending, provider);
    } finally {
      _busy = false;
    }
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> _savePending(
    ({EncryptedVault vault, VaultContext context, Uri server}) pending,
    VaultProvider provider,
  ) async {
    // From here onward even a provider failure may have written a file.
    // Neither close nor retry may trash its key.
    final saved = await _save.execute(pending.vault, provider);
    switch (saved) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        _pending = null;
        final recorded = await _metadata.markStored(
          pending.context,
          pending.vault,
        );
        return Ok(
          VaultCompletion(
            vault: pending.vault,
            warning: switch (recorded) {
              Err(:final failure) => failure,
              Ok() => null,
            },
          ),
        );
    }
  }
}
