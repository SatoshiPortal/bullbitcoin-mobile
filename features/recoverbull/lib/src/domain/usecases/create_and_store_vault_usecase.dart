import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

import '../entities/pending_vault_backup.dart';
import '../entities/encrypted_vault.dart';
import '../entities/recoverbull_network.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_flow_failure.dart';
import '../recoverbull_tor_route.dart';
import '../recoverbull_route_port.dart';
import 'check_server_connection_usecase.dart';
import 'create_encrypted_vault_usecase.dart';
import 'save_vault_to_provider_usecase.dart';
import 'store_vault_key_into_server_usecase.dart';
import 'trash_vault_key_usecase.dart';

/// Owns the secure-vault workflow and its encrypted-only retry state.
final class CreateAndStoreVaultUsecase {
  final LogSink log;
  final CreateEncryptedVaultUsecase create;
  final CheckServerConnectionUsecase check;
  final StoreVaultKeyIntoServerUsecase storeKey;
  final SaveVaultToProviderUsecase save;
  final TrashVaultKeyUsecase? trash;
  PendingVaultBackup? _pending;
  bool _closed = false;

  CreateAndStoreVaultUsecase({
    required this.log,
    required this.create,
    required this.check,
    required this.storeKey,
    required this.save,
    this.trash,
  });

  bool get hasPendingProviderSave => _pending != null;
  bool get trashesAbandonedVaultKeys => trash != null;

  void close() {
    _closed = true;
    _pending = null;
  }

  Future<Result<PendingVaultBackup, RecoverBullFailure>> execute({
    required VaultProvider provider,
    String? password,
    RecoverBullTorRoute? route,
    RecoverBullRoutePort? routeOwner,
    void Function()? onKeyStored,
  }) async {
    if (provider == VaultProvider.iCloud) {
      return const Err(SelectVaultFailure());
    }
    if (_closed) return const Err(VaultCreationFailure());
    try {
      var pending = _pending;
      if (pending == null) {
        if (password == null) return const Err(PasswordNotSetFailure());
        final created = await create.execute();
        if (_closed) return const Err(VaultCreationFailure());
        final ({
          EncryptedVault vault,
          String vaultKey,
          RecoverBullNetwork network,
        })
        value;
        switch (created) {
          case Err():
            return const Err(VaultCreationFailure());
          case Ok(value: final v):
            value = v;
        }
        Future<Result<Null, RecoverBullFailure>> store(
          RecoverBullTorRoute? selected,
        ) async {
          final checked = await check.execute(route: selected);
          if (_closed) return const Err(VaultCreationFailure());
          switch (checked) {
            case Ok(value: true):
              break;
            case Ok():
              return const Err(KeyServerUnavailableFailure());
            case Err(:final failure):
              return Err(failure);
          }
          return storeKey.execute(
            password: password,
            vault: value.vault,
            vaultKey: value.vaultKey,
            route: selected,
          );
        }

        final stored = routeOwner == null
            ? await store(route)
            : await routeOwner.borrowRoute(store);
        if (stored case Err(:final failure)) {
          return Err(storeVaultKeyFailure(failure));
        }
        if (_closed) {
          // No provider save started, so this key cannot belong to a saved file.
          final cleanup = trash;
          if (cleanup != null) {
            unawaited(_trashAbandoned(cleanup, value.vault, password));
          }
          return const Err(VaultCreationFailure());
        }
        pending = PendingVaultBackup(
          vault: value.vault,
          network: value.network,
        );
        _pending = pending;
        onKeyStored?.call();
      }
      // Once any save starts, its key survives even if that save reports failure.
      final result = await save.execute(
        pending: pending,
        provider: provider,
        cancelled: () => _closed,
      );
      if (result is Ok || _closed) _pending = null;
      return result;
    } on Exception {
      log.warning('recoverbull.vault.create_and_store.failed');
      return const Err(VaultCreationFailure());
    }
  }

  Future<void> _trashAbandoned(
    TrashVaultKeyUsecase cleanup,
    EncryptedVault vault,
    String password,
  ) async {
    try {
      log.fine('recoverbull.vault.abandoned_key_trash');
      if (await cleanup.execute(vault: vault, password: password) case Err()) {
        log.warning('recoverbull.vault.abandoned_key.trash.failed');
      }
    } on Exception {
      log.warning('recoverbull.vault.abandoned_key.trash.failed');
    }
  }
}
