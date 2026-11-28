import 'dart:typed_data';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/backup_settings.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_completion.dart';
import '../entities/vault_context.dart';
import '../entities/vault_provider.dart';
import '../entities/vault_passkey.dart';
import '../passkey_password_port.dart';
import '../passkey_secret_port.dart';
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

  /// A sealed vault whose provider write failed, with the provider the user chose.
  ({
    EncryptedVault vault,
    VaultContext context,
    Uri server,
    VaultProvider provider,
  })?
  _pending;
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

  /// The credential is acquired before sealing. Only public metadata survives
  /// into the existing provider-save retry.
  Future<Result<VaultCompletion, RecoverBullFailure>> executePasskey({
    required BackupSettings settings,
    required KeyServerRepository server,
    required VaultProvider provider,
    required VaultPasskey passkey,
    required PasskeySecretPort secrets,
    required PasskeyPasswordPort passwords,
    bool passphraseWarningAccepted = false,
  }) async {
    if (_closed) return const Err(VaultCancelledFailure());
    if (_busy || hasPendingProviderSave) {
      return const Err(VaultContextChangedFailure());
    }
    _busy = true;
    Uint8List? prf;
    try {
      switch (await secrets.get(passkey)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          prf = value;
      }
      if (_closed) return const Err(VaultCancelledFailure());
      if (prf.length != 32) return const Err(VaultPasskeyUnavailableFailure());
      final created = await _create.execute(
        passphraseWarningAccepted: passphraseWarningAccepted,
      );
      if (_closed) return const Err(VaultCancelledFailure());
      switch (created) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          final original = value.vault;
          final vault = EncryptedVault(
            id: original.id,
            salt: original.salt,
            ciphertext: original.ciphertext,
            createdAt: original.createdAt,
            derivationPath: original.derivationPath,
            passkey: passkey,
          );
          final password = passwords.derive(prf, vault);
          prf.fillRange(0, prf.length, 0);
          prf = null;
          switch (await _monitoring.register(settings, vault)) {
            case Err(:final failure):
              return Err(failure);
            case Ok():
              break;
          }
          if (_closed) return const Err(VaultCancelledFailure());
          if (!await _settingsMatch(settings)) {
            return const Err(VaultContextChangedFailure());
          }
          if (_closed) return const Err(VaultCancelledFailure());
          switch (await server.store(vault, password, value.key)) {
            case Err(:final failure):
              return Err(failure);
            case Ok():
              break;
          }
          if (_closed) return const Err(VaultCancelledFailure());
          if (!await _settingsMatch(settings)) {
            return const Err(VaultContextChangedFailure());
          }
          if (_closed) return const Err(VaultCancelledFailure());
          final confirmed = await _fetch.execute(
            settings: settings,
            server: server,
            vault: vault,
            password: password,
          );
          switch (confirmed) {
            case Err(:final failure):
              return Err(failure);
            case Ok(value: final fetched):
              if (fetched.key.hex != value.key.hex) {
                return const Err(VaultDecryptionFailure());
              }
          }
          if (_closed) return const Err(VaultCancelledFailure());
          if (!await _settingsMatch(settings)) {
            return const Err(VaultContextChangedFailure());
          }
          if (_closed) return const Err(VaultCancelledFailure());
          final pending = (
            vault: vault,
            context: value.context,
            server: settings.server,
            provider: provider,
          );
          _pending = pending;
          return await _savePending(pending, provider);
      }
    } finally {
      prf?.fillRange(0, prf.length, 0);
      _busy = false;
    }
  }

  Future<bool> _settingsMatch(BackupSettings expected) async =>
      switch (await _metadata.settings()) {
        Ok(value: final current) =>
          current.permissionGranted &&
              current.server == expected.server &&
              current.sameGeneration(expected),
        Err() => false,
      };

  void close() {
    _closed = true;
    _pending = null;
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> execute({
    required BackupSettings settings,
    required KeyServerRepository server,
    required VaultProvider provider,
    required String password,
    bool passphraseWarningAccepted = false,
  }) async {
    if (_closed) return const Err(VaultCancelledFailure());
    if (_busy || hasPendingProviderSave) {
      return const Err(VaultContextChangedFailure());
    }
    _busy = true;
    try {
      final ({
        EncryptedVault vault,
        VaultContext context,
        Uri server,
        VaultProvider provider,
      })
      pending;
      final created = await _create.execute(
        passphraseWarningAccepted: passphraseWarningAccepted,
      );
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
                  !current.sameGeneration(settings)) {
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
            provider: provider,
          );
          _pending = pending;
      }
      return await _savePending(pending, provider);
    } finally {
      _busy = false;
    }
  }

  /// Retries only the provider write; the original server password stays valid.
  /// Without [provider], the vault goes where the user first chose.
  Future<Result<VaultCompletion, RecoverBullFailure>> retryProviderSave([
    VaultProvider? provider,
  ]) async {
    if (_closed) return const Err(VaultCancelledFailure());
    final pending = _pending;
    if (_busy || pending == null) {
      return const Err(VaultContextChangedFailure());
    }
    _busy = true;
    try {
      return await _savePending(pending, provider ?? pending.provider);
    } finally {
      _busy = false;
    }
  }

  /// Forgets the sealed vault so the user can start over with another password.
  /// Its key stays on the server: a failed write may still have produced a file
  /// that it opens.
  bool abandonPendingProviderSave() {
    if (_busy || _pending == null) return false;
    _pending = null;
    return true;
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> _savePending(
    ({
      EncryptedVault vault,
      VaultContext context,
      Uri server,
      VaultProvider provider,
    })
    pending,
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
