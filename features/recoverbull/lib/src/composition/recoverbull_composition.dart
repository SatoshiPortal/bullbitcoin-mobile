import '../data/datasources/file_storage_datasource.dart';
import '../data/datasources/google_drive_datasource.dart';
import '../data/datasources/recoverbull_remote_datasource.dart';
import '../data/datasources/recoverbull_settings_datasource.dart';
import '../data/recoverbull_repository_impl.dart';
import '../data/file_system_repository.dart';
import '../data/google_drive_repository.dart';
import '../data/debug_google_drive_repository.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/check_server_connection_usecase.dart';
import '../domain/usecases/allow_permission_usecase.dart';
import '../domain/usecases/fetch_permission_usecase.dart';
import '../domain/usecases/connect_to_key_server_usecase.dart';
import '../domain/usecases/create_encrypted_vault_usecase.dart';
import '../domain/usecases/decrypt_vault_usecase.dart';
import '../domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import '../domain/usecases/fetch_recoverbull_url_usecase.dart';
import '../domain/usecases/fetch_vault_key_from_server_usecase.dart';
import '../domain/usecases/google_drive/connect_google_drive_usecase.dart';
import '../domain/usecases/google_drive/delete_drive_file_usecase.dart';
import '../domain/usecases/google_drive/export_drive_file_usecase.dart';
import '../domain/usecases/google_drive/fetch_all_drive_file_metadata_usecase.dart';
import '../domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import '../domain/usecases/google_drive/fetch_vault_from_drive_usecase.dart';
import '../domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import '../domain/usecases/pick_vault_usecase.dart';
import '../domain/usecases/record_local_attempt_usecase.dart';
import '../domain/usecases/register_monitored_backup_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/save_file_to_system_usecase.dart';
import '../domain/usecases/store_recoverbull_url_usecase.dart';
import '../domain/usecases/store_vault_key_into_server_usecase.dart';
import '../domain/usecases/verify_decrypted_vault_usecase.dart';
import '../domain/usecases/discover_drive_backups_usecase.dart';
import '../data/google_drive_backup_discovery_adapter.dart';
import '../google_drive/presentation/bloc.dart';
import '../google_drive/recoverbull_google_drive_router.dart';
import '../presentation/bloc.dart';
import '../router/recoverbull_router.dart';
import '../router/flow_type.dart';
import '../router/recoverbull_flow.dart';
import '../google_drive/ui/screens/drive_vaults_list_page.dart';
import '../ui/screens/server_confirmation_page.dart';
import '../ui/screens/settings_page.dart';
import '../ui/screens/recoverbull_settings_cubit.dart';
import '../google_drive/presentation/state.dart';
import '../attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_logger/bull_logger.dart' show LogSink;
import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../domain/recoverbull_default_wallets_port.dart';
import '../domain/recoverbull_seed_port.dart';
import '../domain/recoverbull_settings_port.dart';
import '../domain/repositories/recoverbull_wallet_repository.dart';
import '../domain/repositories/recoverbull_repository.dart';
import '../public/recoverbull.dart';

final class RecoverBullFeature {
  final LogSink log;
  final RecoverBullCore _core;
  final RecoverBullLifecycle lifecycle;
  final RecoverBullRepository _repository;
  final RecoverBullBloc Function({
    required RecoverBullFlow flow,
    EncryptedVault? vault,
  })
  _newBloc;
  final RecoverBullGoogleDriveBloc Function({required RecoverBullFlow flow})
  _newDriveBloc;
  final Future<RecoverBullRecoveryResult> Function({
    required String encryptedBackup,
    required String password,
  })
  _recoverBackup;
  final Future<bool> Function() _ensureTorReady;
  final CheckServerConnectionUsecase _check;
  final RecoverBullAttemptMonitoringController _attemptMonitoring;

  const RecoverBullFeature._(
    this.log,
    this._core,
    this.lifecycle,
    this._repository,
    this._newBloc,
    this._newDriveBloc,
    this._recoverBackup,
    this._ensureTorReady,
    this._check,
    this._attemptMonitoring,
  );

  static Future<RecoverBullFeature> create({
    required RecoverBullConfig config,
    required RecoverBullWalletRepository wallets,
    required RecoverBullSeedPort seeds,
    required RecoverBullDefaultWalletsPort defaultWallets,
    required RecoverBullSettingsPort settings,
    required Tor tor,
    required LogSink log,
    RecoverBullTiming? timing,
    Future<void> Function()? onWalletUpdated,
  }) async {
    final core = RecoverBullCore(
      config: config,
      dependencies: RecoverBullDependencies(timing: timing),
    );
    final database = await core.lifecycle.openDatabase(
      config.databasePath,
      initialPermissionGranted: config.initialPermissionGranted,
    );
    final attemptMonitoringStore = RecoverBullAttemptMonitoringStore(database);
    final settingsDatasource = RecoverbullSettingsDatasource(
      database: database,
      defaultServer: config.effectiveDefaultServer,
    );
    final remote = RecoverBullRemoteDatasource(
      recoverbullSettingsDatasource: settingsDatasource,
      log: log,
      timing: core.dependencies.timing,
    );
    final repository = RecoverBullRepositoryImpl(
      log: log,
      remoteDatasource: remote,
      recoverbullSettingsDatasource: settingsDatasource,
    );
    final files = FileSystemRepository(
      log: log,
      datasource: FileStorageDatasource(),
    );
    final productionDrive = GoogleDriveRepositoryImpl(
      log: log,
      datasource: GoogleDriveAppDatasource(log: log),
    );
    final drive = selectGoogleDriveRepository(production: productionDrive);
    unawaited(
      DiscoverDriveBackupsUsecase(
        drive: GoogleDriveBackupDiscoveryAdapter(drive),
        store: attemptMonitoringStore,
        log: log,
      ).execute(),
    );
    final ensureTor = EnsureRecoverBullTorSessionUsecase(
      tor.embedded,
      settings,
      tor,
      timing: core.dependencies.timing,
      torHttpClientFactory: const TorHttpClientFactory(),
    );
    final decryptVault = DecryptVaultUsecase(recoverBullRepository: repository);
    final restoreVault = RestoreVaultUsecase(
      log: log,
      createDefaultWalletsUsecase: defaultWallets,
    );
    final check = CheckServerConnectionUsecase(
      repository: repository,
      ensureTor: ensureTor,
      log: log,
    );
    final productionAttemptMonitoringRemote =
        RecoverBullAttemptMonitoringRemoteAdapter(
          datasource: remote,
          routeFactory: () async {
            final result = await ensureTor.execute();
            return switch (result) {
              Ok(:final value) => value,
              Err(:final failure) => throw StateError(
                failure.logMessage ?? 'route unavailable',
              ),
            };
          },
        );
    final attemptMonitoring = RecoverBullAttemptMonitoring(
      attemptMonitoringStore,
      enabled: (await database.select(database.recoverbullState).getSingle())
          .attemptMonitoringEnabled,
      poll: productionAttemptMonitoringRemote.poll,
      log: log,
    );
    final fetchVaultKey = FetchVaultKeyFromServerUsecase(
      repository: repository,
      ensureTor: ensureTor,
      recordAttempt: RecordLocalAttemptUsecase(
        attemptMonitoringStore,
        remote: productionAttemptMonitoringRemote,
      ),
      alertPort: attemptMonitoring,
      log: log,
    );
    final verifyDecryptedVault = VerifyDecryptedVaultUsecase(wallets);
    RecoverBullBloc newBloc({
      required RecoverBullFlow flow,
      EncryptedVault? vault,
    }) => RecoverBullBloc(
      log: log,
      flow: flow,
      preSelectedVault: vault,
      pickVaultUsecase: PickVaultUsecase(fileSystemRepository: files),
      saveFileToSystemUsecase: SaveFileToSystemUsecase(
        fileSystemRepository: files,
      ),
      createEncryptedVaultUsecase: CreateEncryptedVaultUsecase(
        log: log,
        recoverBullRepository: repository,
        seedRepository: seeds,
        walletRepository: wallets,
      ),
      storeVaultKeyIntoServerUsecase: StoreVaultKeyIntoServerUsecase(
        repository: repository,
        ensureTor: ensureTor,
        log: log,
      ),
      registerMonitoredBackupUsecase: RegisterMonitoredBackupUsecase(
        attemptMonitoringStore,
      ),
      checkKeyServerConnectionUsecase: check,
      connectToKeyServerUsecase: ConnectToKeyServerUsecase(
        check: check,
        ensureTor: ensureTor,
        log: log,
      ),
      fetchVaultKeyFromServerUsecase: fetchVaultKey,
      decryptVaultUsecase: decryptVault,
      restoreVaultUsecase: restoreVault,
      connectToGoogleDriveUsecase: ConnectToGoogleDriveUsecase(
        driveRepository: drive,
      ),
      saveToGoogleDriveUsecase: SaveVaultToGoogleDriveUsecase(
        driveRepository: drive,
      ),
      fetchLatestGoogleDriveVaultUsecase: FetchLatestGoogleDriveVaultUsecase(
        driveRepository: drive,
      ),
      ensureRecoverBullTorSessionUsecase: ensureTor,
      watchTorConnectionUsecase: tor.embedded.watcher,
      lifecycle: core.lifecycle,
      verifyDecryptedVaultUsecase: verifyDecryptedVault,
      onWalletUpdated: onWalletUpdated,
    );
    RecoverBullGoogleDriveBloc newDriveBloc({required RecoverBullFlow flow}) =>
        RecoverBullGoogleDriveBloc(
          log: log,
          flow: flow,
          fetchAllDriveFileMetadataUsecase: FetchAllDriveFileMetadataUsecase(
            driveRepository: drive,
          ),
          fetchDriveBackupUsecase: FetchVaultFromDriveUsecase(
            driveRepository: drive,
          ),
          deleteDriveFileUsecase: DeleteDriveFileUsecase(
            driveRepository: drive,
          ),
          exportDriveFileUsecase: ExportDriveFileUsecase(
            driveRepository: drive,
            fileSystemRepository: files,
          ),
        );
    Future<RecoverBullRecoveryResult> recoverBackup({
      required String encryptedBackup,
      required String password,
    }) async {
      final EncryptedVault vault;
      try {
        vault = EncryptedVault(file: encryptedBackup);
      } catch (_) {
        log.warning(
          'recoverbull.recover_backup.invalid_vault',
          error: 'Invalid encrypted backup format',
        );
        return const RecoverBullRecoveryResult(restored: false);
      }
      final keyResult = await fetchVaultKey.execute(
        vault: vault,
        password: password,
      );
      final vaultKey = switch (keyResult) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (vaultKey == null) {
        return const RecoverBullRecoveryResult(restored: false);
      }
      final decryptedResult = decryptVault.execute(
        vault: vault,
        vaultKey: vaultKey,
      );
      final decryptedVault = switch (decryptedResult) {
        Ok(:final value) => value,
        Err() => null,
      };
      if (decryptedVault == null) {
        return const RecoverBullRecoveryResult(restored: false);
      }
      final belongsToCurrentWallet = await verifyDecryptedVault.execute(
        decryptedVault: decryptedVault,
      );
      switch (belongsToCurrentWallet) {
        case Ok(value: VaultVerificationResult.match):
        case Ok(value: VaultVerificationResult.noCurrentWallet):
          break;
        case Ok(value: VaultVerificationResult.mismatch):
        case Err():
          return const RecoverBullRecoveryResult(restored: false);
      }
      final restored = await restoreVault.execute(
        decryptedVault: decryptedVault,
      );
      if (restored case Err()) {
        return const RecoverBullRecoveryResult(restored: false);
      }
      try {
        await core.lifecycle.markVerified();
      } catch (_) {
        log.warning('recoverbull.lifecycle.mark_verified_failed');
      }
      try {
        await onWalletUpdated?.call();
      } catch (_) {
        log.warning('recoverbull.wallet_refresh.restore_failed');
      }
      return const RecoverBullRecoveryResult(restored: true);
    }

    Future<bool> ensureTorReady() async {
      final result = await ensureTor.execute();
      return switch (result) {
        Ok(:final value) => value.close().then((_) => true),
        Err() => false,
      };
    }

    return RecoverBullFeature._(
      log,
      core,
      core.lifecycle,
      repository,
      newBloc,
      newDriveBloc,
      recoverBackup,
      ensureTorReady,
      check,
      attemptMonitoring,
    );
  }

  /// Fetches, decrypts, and restores one encrypted vault through the feature's
  /// configured Tor/key-server and wallet capabilities.
  Future<RecoverBullRecoveryResult> recoverBackup({
    required String encryptedBackup,
    required String password,
  }) => _recoverBackup(encryptedBackup: encryptedBackup, password: password);

  /// Ensures the configured Tor route is ready and closes the probe session.
  Future<bool> ensureTorReady() => _ensureTorReady();

  RecoverBullAttemptMonitoringController get attemptMonitoring =>
      _attemptMonitoring;

  Future<RecoverBullHealth> checkService() async {
    try {
      final result = await _check.execute();
      return switch (result) {
        Ok(:final value) when value => RecoverBullHealth.online,
        Err(:final failure)
            when failure is KeyServerHealthCheckTimeoutFailure =>
          RecoverBullHealth.timeout,
        Err(:final failure)
            when failure is RecoverBullTemporarilyUnavailableFailure =>
          RecoverBullHealth.temporarilyUnavailable,
        _ => RecoverBullHealth.offline,
      };
    } catch (_) {
      return RecoverBullHealth.offline;
    }
  }

  Future<RecoverBullStatus> status() => _core.status();
  Future<RecoverBullServerSettings> serverSettings() => _core.serverSettings();
  Future<void> setServer(Uri server) => _core.setServer(server);
  Future<void> setPermission(bool granted) => _core.setPermission(granted);
  Future<void> markBackupStored() => _core.markBackupStored();
  Future<void> markBackupVerified() => _core.markBackupVerified();
  List<RouteBase> get routes => [
    for (final route in RecoverBullRoute.values)
      GoRoute(
        name: route.name,
        path: route.path,
        builder: (context, state) {
          final extra = state.extra is RecoverBullFlowsExtra
              ? state.extra! as RecoverBullFlowsExtra
              : RecoverBullFlowsExtra(flow: _flow(route));
          if (route == RecoverBullRoute.recoverbullSettings) {
            return RecoverBullFlowNavigator(
              flow: RecoverBullFlow.settings,
              fetchPermissionUsecase: FetchPermissionUsecase(
                recoverBullRepository: _repository,
              ),
              settingsPageBuilder: (context) => SettingsPage(
                log: log,
                cubit: RecoverBullSettingsCubit(
                  log: log,
                  fetchUrl: FetchRecoverbullUrlUsecase(
                    recoverBullRepository: _repository,
                  ),
                  storeUrl: StoreRecoverbullUrlUsecase(
                    recoverBullRepository: _repository,
                  ),
                  monitoring: _attemptMonitoring,
                ),
              ),
              requestPermissionPageBuilder: (context) => RequestPermissionPage(
                log: log,
                fetchUrlUsecase: FetchRecoverbullUrlUsecase(
                  recoverBullRepository: _repository,
                ),
                allowPermissionUsecase: AllowPermissionUsecase(
                  recoverBullRepository: _repository,
                ),
              ),
            );
          }
          return BlocProvider(
            create: (_) => _newBloc(flow: extra.flow, vault: extra.vault),
            child: RecoverBullFlowNavigator(
              flow: extra.flow,
              fetchPermissionUsecase: FetchPermissionUsecase(
                recoverBullRepository: _repository,
              ),
              settingsPageBuilder: (context) => SettingsPage(
                log: log,
                cubit: RecoverBullSettingsCubit(
                  log: log,
                  fetchUrl: FetchRecoverbullUrlUsecase(
                    recoverBullRepository: _repository,
                  ),
                  storeUrl: StoreRecoverbullUrlUsecase(
                    recoverBullRepository: _repository,
                  ),
                  monitoring: _attemptMonitoring,
                ),
              ),
              requestPermissionPageBuilder: (context) => RequestPermissionPage(
                log: log,
                fetchUrlUsecase: FetchRecoverbullUrlUsecase(
                  recoverBullRepository: _repository,
                ),
                allowPermissionUsecase: AllowPermissionUsecase(
                  recoverBullRepository: _repository,
                ),
              ),
            ),
          );
        },
      ),
    GoRoute(
      name: RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.name,
      path: RecoverBullGoogleDriveRoute.recoverbullListDriveVaults.path,
      builder: (context, state) {
        final extra = state.extra is RecoverBullFlowsExtra
            ? state.extra! as RecoverBullFlowsExtra
            : const RecoverBullFlowsExtra(flow: RecoverBullFlow.recoverVault);
        return BlocProvider(
          create: (_) => _newDriveBloc(flow: extra.flow),
          child:
              BlocListener<
                RecoverBullGoogleDriveBloc,
                RecoverBullGoogleDriveState
              >(
                listenWhen: (previous, current) =>
                    previous.selectedVault != current.selectedVault,
                listener: (context, driveState) {
                  final vault = driveState.selectedVault;
                  if (vault != null) {
                    context.pushNamed(
                      RecoverBullRoute.recoverbullFlows.name,
                      extra: RecoverBullFlowsExtra(
                        flow: extra.flow,
                        vault: vault,
                      ),
                    );
                  }
                },
                child: const DriveVaultsListPage(),
              ),
        );
      },
    ),
  ];

  static RecoverBullFlow _flow(RecoverBullRoute route) => switch (route) {
    RecoverBullRoute.recoverbullFlows => RecoverBullFlow.recoverVault,
    RecoverBullRoute.recoverbullSecureVault => RecoverBullFlow.secureVault,
    RecoverBullRoute.recoverbullRecoverVault => RecoverBullFlow.recoverVault,
    RecoverBullRoute.recoverbullTestVault => RecoverBullFlow.testVault,
    RecoverBullRoute.recoverbullViewVaultKey => RecoverBullFlow.viewVaultKey,
    RecoverBullRoute.recoverbullSettings => RecoverBullFlow.settings,
  };
}
