import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../domain/entities/backup_settings.dart';
import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_completion.dart';
import '../domain/entities/vault_provider.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/complete_vault_usecase.dart';
import '../domain/usecases/manage_backup_settings_usecase.dart';
import '../domain/usecases/pick_vault_usecase.dart';
import '../domain/usecases/derive_vault_key_usecase.dart';
import '../domain/usecases/list_drive_vaults_usecase.dart';
import '../domain/usecases/read_drive_vault_usecase.dart';
import '../domain/usecases/delete_drive_vault_usecase.dart';
import '../domain/usecases/export_drive_vault_usecase.dart';
import '../domain/usecases/manage_vault_session_usecase.dart';

final class VaultFlowState {
  final bool busy;
  final bool hasPendingProviderSave;
  final BackupSettings? settings;
  final EncryptedVault? vault;
  final List<DriveFileMetadata>? files;
  final VaultCompletion? completion;
  final RecoverBullFailure? failure;

  const VaultFlowState({
    this.busy = false,
    this.hasPendingProviderSave = false,
    this.settings,
    this.vault,
    this.files,
    this.completion,
    this.failure,
  });
}

/// Holds business results only. Passwords, focus and reveal state belong to the
/// protected screen; neither keys nor passwords are retained in cubit state.
final class VaultFlowCubit extends Cubit<VaultFlowState> {
  final ManageBackupSettingsUsecase _settings;
  final ({
    PickVaultUsecase pick,
    ListDriveVaultsUsecase list,
    ReadDriveVaultUsecase select,
    DeleteDriveVaultUsecase delete,
    ExportDriveVaultUsecase export,
  })
  _files;
  final ManageVaultSessionUsecase? _session;
  final CompleteVaultUsecase _complete;
  final DeriveVaultKeyUsecase? _localKey;
  final RecoverBullFailure unavailable;
  bool _closing = false;

  VaultFlowCubit(
    this._settings,
    this._files,
    this._session,
    this._complete, {
    required this.unavailable,
    EncryptedVault? vault,
    this._localKey,
  }) : super(VaultFlowState(vault: vault));

  void _publish({
    bool busy = false,
    BackupSettings? settings,
    EncryptedVault? vault,
    List<DriveFileMetadata>? files,
    VaultCompletion? completion,
    RecoverBullFailure? failure,
  }) {
    if (_closing || isClosed) return;
    emit(
      VaultFlowState(
        busy: busy,
        hasPendingProviderSave: _session?.hasPendingProviderSave ?? false,
        settings: settings ?? state.settings,
        vault: vault ?? state.vault,
        files: files,
        completion: completion,
        failure: failure,
      ),
    );
  }

  Future<T?> _run<T>(
    Future<Result<T, RecoverBullFailure>> Function() action,
  ) async {
    if (state.busy || _closing || isClosed) return null;
    _publish(busy: true, files: state.files);
    final result = await action();
    if (_closing || isClosed) return null;
    switch (result) {
      case Err(:final failure):
        _publish(failure: failure, files: state.files);
        return null;
      case Ok(:final value):
        _publish(files: state.files);
        return value;
    }
  }

  Future<void> settings([
    BackupSettingsAction action = const ReadBackupSettings(),
  ]) async {
    final value = await _run(() => _settings.execute(action));
    if (value != null) _publish(settings: value);
  }

  Future<void> pick() async {
    final value = await _run(_files.pick.execute);
    if (value != null) _publish(vault: value);
  }

  Future<void> list() async {
    final value = await _run(_files.list.execute);
    if (value != null) _publish(files: value);
  }

  Future<void> select(DriveFileMetadata file) async {
    final value = await _run(() => _files.select.execute(file));
    if (value != null) _publish(vault: value);
  }

  Future<void> export(DriveFileMetadata file) async {
    await _run(() => _files.export.execute(file));
  }

  Future<void> delete(DriveFileMetadata file) async {
    await _run(() => _files.delete.execute(file));
  }

  Future<void> connect({bool newRoute = false}) async {
    await _run(
      () =>
          _session?.connect(newRoute: newRoute) ??
          Future.value(Err(unavailable)),
    );
  }

  Future<void> create(VaultProvider provider, String password) async {
    final value = await _run(
      () =>
          _session?.create(provider: provider, password: password) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  Future<void> retryProviderSave(VaultProvider provider) async {
    final value = await _run(
      () =>
          _session?.retryProviderSave(provider) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  Future<void> verify(String password, BitcoinNetwork? network) async {
    final vault = state.vault;
    if (vault == null) return;
    final value = await _run(
      () =>
          _session?.verify(
            vault: vault,
            password: password,
            recoveryNetwork: network,
          ) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(completion: value);
  }

  Future<void> manual(VaultKey key, BitcoinNetwork? network) async {
    final vault = state.vault;
    if (vault == null) return;
    final value = await _run(
      () => _complete.execute(
        vault: vault,
        key: key,
        recoveryNetwork: network,
        cancelled: () => _closing || isClosed,
      ),
    );
    if (value != null) _publish(completion: value);
  }

  Future<VaultKey?> deriveKey() async {
    final vault = state.vault;
    final derive = _localKey;
    if (vault == null || derive == null) return null;
    return _run(() => derive.execute(vault));
  }

  Future<VaultKey?> reveal(String password) async {
    final vault = state.vault;
    if (vault == null) return null;
    return _run(
      () =>
          _session?.reveal(vault: vault, password: password) ??
          Future.value(Err<VaultKey, RecoverBullFailure>(unavailable)),
    );
  }

  @override
  Future<void> close() async {
    // Fence callbacks immediately, while the session finishes accounting for
    // any network or storage operation already committed.
    _closing = true;
    final closing = _session?.close();
    await super.close();
    await closing;
  }
}
