import 'dart:async';

import 'package:bull_tor/tor.dart'
    show TorConnecting, TorConnectionState, TorReady, TorUninitialized;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../domain/entities/backup_settings.dart';
import '../domain/entities/drive_file_metadata.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_completion.dart';
import '../domain/entities/vault_provider.dart';
import '../domain/entities/vault_passkey.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/complete_vault_usecase.dart';
import '../domain/usecases/manage_backup_settings_usecase.dart';
import '../domain/usecases/pick_vault_usecase.dart';
import '../domain/usecases/list_drive_vaults_usecase.dart';
import '../domain/usecases/read_drive_vault_usecase.dart';
import '../domain/usecases/delete_drive_vault_usecase.dart';
import '../domain/usecases/export_drive_vault_usecase.dart';
import '../domain/usecases/manage_vault_session_usecase.dart';

enum KeyServerStatus { unknown, connecting, online, offline }

final class VaultFlowState {
  final bool busy;
  final KeyServerStatus keyServer;

  /// Failed key-server attempts on the current route; a new route starts again from zero.
  final int keyServerFailures;

  /// When the running key-server probe gives up; null while none runs.
  final DateTime? keyServerDeadline;
  final TorConnectionState tor;
  final bool hasPendingProviderSave;
  final BackupSettings? settings;
  final EncryptedVault? vault;
  final List<DriveFileMetadata>? files;
  final VaultCompletion? completion;
  final RecoverBullFailure? failure;

  const VaultFlowState({
    this.busy = false,
    this.keyServer = KeyServerStatus.unknown,
    this.keyServerFailures = 0,
    this.keyServerDeadline,
    this.tor = const TorUninitialized(),
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
  final RecoverBullFailure unavailable;
  StreamSubscription<TorConnectionState>? _torSubscription;
  final bool Function() _snowflakeAvailable;
  bool _closing = false;

  /// A key-server probe runs beside the flow's operations rather than as one:
  /// a Tor bootstrap can take minutes, and recovering with the vault key needs
  /// no server, so it must not wait for it.
  bool _connecting = false;
  bool get passkeysAvailable => _session?.passkeysAvailable ?? false;

  VaultFlowCubit(
    this._settings,
    this._files,
    this._session,
    this._complete, {
    required this.unavailable,
    EncryptedVault? vault,
    Stream<TorConnectionState>? tor,
    bool Function()? snowflakeAvailable,
  }) : _snowflakeAvailable = snowflakeAvailable ?? (() => false),
       super(VaultFlowState(vault: vault)) {
    _torSubscription = tor?.listen((value) {
      if (_closing || isClosed) return;
      // A ready route stays ready through Tor's own directory refreshes, which
      // briefly report Connecting without any blockage.
      if (state.tor is TorReady &&
          value is TorConnecting &&
          value.diagnostic == null) {
        return;
      }
      emit(_copy(tor: value));
    });
  }

  VaultFlowState _copy({
    KeyServerStatus? keyServer,
    int? keyServerFailures,
    TorConnectionState? tor,
    bool? hasPendingProviderSave,
    RecoverBullFailure? Function()? failure,
    DateTime? Function()? keyServerDeadline,
  }) => VaultFlowState(
    busy: state.busy,
    keyServer: keyServer ?? state.keyServer,
    keyServerFailures: keyServerFailures ?? state.keyServerFailures,
    keyServerDeadline: keyServerDeadline == null
        ? state.keyServerDeadline
        : keyServerDeadline(),
    tor: tor ?? state.tor,
    hasPendingProviderSave:
        hasPendingProviderSave ?? state.hasPendingProviderSave,
    settings: state.settings,
    vault: state.vault,
    files: state.files,
    completion: state.completion,
    failure: failure == null ? state.failure : failure(),
  );

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
        keyServer: state.keyServer,
        keyServerFailures: state.keyServerFailures,
        keyServerDeadline: state.keyServerDeadline,
        tor: state.tor,
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

  /// Runs an opening operation without publishing its result as the selection.
  Future<Result<T, RecoverBullFailure>?> _openVaultOperation<T>(
    Future<Result<T, RecoverBullFailure>> Function() action,
  ) async {
    if (state.busy || _closing || isClosed) return null;
    _publish(busy: true, files: state.files);
    final result = await action();
    if (_closing || isClosed) return null;
    _publish(files: state.files);
    return result;
  }

  Future<Result<EncryptedVault, RecoverBullFailure>?> openPickedVault() =>
      _openVaultOperation(_files.pick.execute);

  Future<Result<List<DriveFileMetadata>, RecoverBullFailure>?>
  openDriveList() => _openVaultOperation(_files.list.execute);

  Future<Result<EncryptedVault, RecoverBullFailure>?> openDriveVault(
    DriveFileMetadata file,
  ) => _openVaultOperation(() => _files.select.execute(file));

  /// Adopts only the vault accepted by the active selection machine.
  bool adoptSelectedVault(EncryptedVault vault) {
    if (state.busy || _closing || isClosed) return false;
    _publish(vault: vault, files: state.files);
    return true;
  }

  Future<void> export(DriveFileMetadata file) async {
    await _run(() => _files.export.execute(file));
  }

  Future<void> delete(DriveFileMetadata file) async {
    await _run(() => _files.delete.execute(file));
  }

  /// Whether the user's Tor settings let this flow restart through Snowflake.
  bool get snowflakeAvailable => _snowflakeAvailable();

  /// Probes the key server through this flow's route; the connection screen
  /// calls it once consent is granted, and again on Retry or New route.
  Future<void> connect({
    bool newRoute = false,
    bool restartTor = false,
    bool viaSnowflake = false,
  }) async {
    if (_connecting || _closing || isClosed) return;
    _connecting = true;
    emit(
      _copy(
        keyServer: KeyServerStatus.connecting,
        keyServerFailures: newRoute || restartTor || viaSnowflake ? 0 : null,
        failure: () => null,
        keyServerDeadline: () => null,
      ),
    );
    final Result<void, RecoverBullFailure> result;
    try {
      result =
          await (_session?.connect(
                newRoute: newRoute,
                restartTor: restartTor,
                viaSnowflake: viaSnowflake,
                onProbe: (deadline) {
                  if (_closing || isClosed) return;
                  emit(_copy(keyServerDeadline: () => deadline));
                },
              ) ??
              Future.value(Err<void, RecoverBullFailure>(unavailable)));
    } finally {
      _connecting = false;
    }
    if (_closing || isClosed) return;
    emit(switch (result) {
      Ok() => _copy(
        keyServer: KeyServerStatus.online,
        keyServerDeadline: () => null,
      ),
      Err(:final failure) => _copy(
        keyServer: KeyServerStatus.offline,
        keyServerDeadline: () => null,
        keyServerFailures: state.keyServerFailures + 1,
        failure: () => failure,
      ),
    });
  }

  /// Clears a failure once the screen has shown it.
  void clearFailure() {
    if (_closing || isClosed || state.failure == null) return;
    _publish(files: state.files);
  }

  Future<void> create(
    VaultProvider provider,
    String password, {
    bool passphraseWarningAccepted = false,
  }) async {
    final value = await _run(
      () =>
          _session?.create(
            provider: provider,
            password: password,
            passphraseWarningAccepted: passphraseWarningAccepted,
          ) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  Future<VaultPasskey?> createPasskey() => _run(
    () =>
        _session?.createPasskey() ??
        Future.value(Err<VaultPasskey, RecoverBullFailure>(unavailable)),
  );

  Future<void> createWithPasskey(
    VaultProvider provider,
    VaultPasskey passkey, {
    bool passphraseWarningAccepted = false,
  }) async {
    final value = await _run(
      () =>
          _session?.createWithPasskey(
            provider: provider,
            passkey: passkey,
            passphraseWarningAccepted: passphraseWarningAccepted,
          ) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  Future<void> verifyPasskey(
    BitcoinNetwork? network, {
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    final vault = state.vault;
    if (vault == null) return;
    final value = await _run(
      () =>
          _session?.verifyPasskey(
            vault: vault,
            recoveryNetwork: network,
            passphrase: passphrase,
            allowUnverified: allowUnverified,
          ) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(completion: value);
  }

  /// Without [provider], the vault goes where the user first chose.
  Future<void> retryProviderSave([VaultProvider? provider]) async {
    final value = await _run(
      () =>
          _session?.retryProviderSave(provider) ??
          Future.value(Err<VaultCompletion, RecoverBullFailure>(unavailable)),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  /// Retries creating the wallets of a recovery whose import committed without them.
  Future<void> retryWallets(VaultCompletion completion) async {
    final value = await _run(
      () async => Ok<VaultCompletion, RecoverBullFailure>(
        await _complete.retryWallets(completion),
      ),
    );
    if (value != null) _publish(vault: value.vault, completion: value);
  }

  /// Forgets a backup whose save did not complete, so the user can start over.
  void abandonPendingProviderSave() {
    if (state.busy || _closing || isClosed) return;
    if (_session?.abandonPendingProviderSave() ?? false) {
      emit(_copy(hasPendingProviderSave: false));
    }
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

  Future<void> manual(
    VaultKey key,
    BitcoinNetwork? network, {
    String passphrase = '',
    bool allowUnverified = false,
    BackupSettings? capturedSettings,
  }) async {
    final vault = state.vault;
    if (vault == null) return;
    final value = await _run(
      () => _complete.execute(
        vault: vault,
        key: key,
        recoveryNetwork: network,
        cancelled: () => _closing || isClosed,
        passphrase: passphrase,
        allowUnverified: allowUnverified,
        capturedSettings: capturedSettings,
      ),
    );
    if (value != null) _publish(completion: value);
  }

  Future<({VaultKey key, BackupSettings settings})?> verificationKey(
    String password,
  ) async {
    final vault = state.vault;
    if (vault == null) return null;
    return _run(
      () =>
          _session?.verificationKey(vault: vault, password: password) ??
          Future.value(
            Err<({VaultKey key, BackupSettings settings}), RecoverBullFailure>(
              unavailable,
            ),
          ),
    );
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
    await _torSubscription?.cancel();
    final closing = _session?.close();
    await super.close();
    await closing;
  }
}
