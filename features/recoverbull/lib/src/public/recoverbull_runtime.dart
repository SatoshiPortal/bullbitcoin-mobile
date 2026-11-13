import 'package:bull_logger/bull_logger.dart';
import 'package:bull_tor/tor.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show Secrets;

import '../data/attempt_monitoring_repository_impl.dart';
import '../data/backup_metadata_repository_impl.dart';
import '../data/database/recoverbull_storage.dart';
import '../data/datasources/google_drive_datasource.dart';
import '../data/google_drive_repository.dart';
import '../data/key_server_session_repository_impl.dart';
import '../data/secrets_vault_repository.dart';
import '../data/vault_file_repository_impl.dart';
import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/recoverbull_flow.dart';
import '../domain/recoverbull_environment_port.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/recoverbull_legacy_settings_port.dart';
import '../domain/recoverbull_route_port.dart';
import '../domain/recoverbull_wallet_port.dart';
import '../domain/usecases/acknowledge_backup_alerts_usecase.dart';
import '../domain/usecases/check_backup_monitoring_usecase.dart';
import '../domain/usecases/check_backup_server_usecase.dart';
import '../domain/usecases/complete_vault_usecase.dart';
import '../domain/usecases/create_and_store_vault_usecase.dart';
import '../domain/usecases/create_vault_usecase.dart';
import '../domain/usecases/discover_drive_backups_usecase.dart';
import '../domain/usecases/fetch_vault_key_usecase.dart';
import '../domain/usecases/import_backup_settings_usecase.dart';
import '../domain/usecases/manage_backup_settings_usecase.dart';
import '../domain/usecases/pick_vault_usecase.dart';
import '../domain/usecases/list_drive_vaults_usecase.dart';
import '../domain/usecases/read_drive_vault_usecase.dart';
import '../domain/usecases/delete_drive_vault_usecase.dart';
import '../domain/usecases/export_drive_vault_usecase.dart';
import '../domain/usecases/manage_vault_session_usecase.dart';
import '../domain/usecases/open_key_server_usecase.dart';
import '../domain/usecases/read_backup_status_usecase.dart';
import '../domain/usecases/recover_server_vault_usecase.dart';
import '../domain/usecases/parse_vault_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/save_vault_usecase.dart';
import '../domain/usecases/start_backup_monitoring_usecase.dart';
import '../domain/usecases/start_vault_flow_usecase.dart';
import '../domain/usecases/test_vault_usecase.dart';
import '../domain/usecases/watch_backup_monitoring_usecase.dart';
import '../presentation/backup_monitoring_cubit.dart';
import '../presentation/vault_flow_cubit.dart';
import '../presentation/vault_flow_presentation.dart';

/// Private package composition, never exported to consumers or the shell.
final class RecoverBullRuntime {
  final RecoverBullStorage _storage;
  final SecretsVaultRepository _vaults;
  final RecoverBullWalletPort _wallets;
  final StartVaultFlowUsecase _startFlow;
  final GoogleDriveRepositoryImpl _drive;
  final VaultFileRepositoryImpl _files;
  final KeyServerSessionRepositoryImpl _sessions;
  final BackupMetadataRepositoryImpl? _metadata;
  final AttemptMonitoringRepositoryImpl? _monitoring;
  final RecoverBullFailure unavailable;
  final StartBackupMonitoringUsecase? coldStart;

  RecoverBullRuntime._(
    this._storage,
    this._vaults,
    this._wallets,
    this._startFlow,
    this._drive,
    this._files,
    this._sessions,
    this._metadata,
    this._monitoring,
    this.unavailable,
    this.coldStart,
  );

  static Future<RecoverBullRuntime> open({
    required String databasePath,
    required DatabaseKey databaseKey,
    required Secrets secrets,
    required RecoverBullWalletPort wallets,
    required RecoverBullEnvironmentPort environment,
    required RecoverBullLegacySettingsPort legacy,
    required RecoverBullRoutePort routes,
    required TorHttpClientFactory clients,
  }) async {
    final storage = RecoverBullStorage(databasePath, key: databaseKey);
    final vaults = SecretsVaultRepository(secrets);
    final drive = GoogleDriveRepositoryImpl(
      datasource: GoogleDriveAppDatasource(),
    );
    try {
      final files = VaultFileRepositoryImpl();
      final sessions = KeyServerSessionRepositoryImpl(routes, clients);
      BackupMetadataRepositoryImpl? metadata;
      AttemptMonitoringRepositoryImpl? monitoring;
      RecoverBullFailure unavailable = const RecoverBullJournalFailure();
      try {
        final database = await storage.open();
        metadata = BackupMetadataRepositoryImpl(database);
        monitoring = AttemptMonitoringRepositoryImpl(database, durable: true);
      } on Exception {
        unavailable = storage.unavailableFailure ?? unavailable;
        log.warning('recoverbull.storage.unavailable');
      }
      StartBackupMonitoringUsecase? coldStart;
      if (metadata != null && monitoring != null) {
        if (await ImportBackupSettingsUsecase(metadata, legacy).execute()
            case Err()) {
          log.warning('recoverbull.settings.import.unavailable');
        }
        coldStart = StartBackupMonitoringUsecase(
          DiscoverDriveBackupsUsecase(drive, vaults, metadata, monitoring),
          CheckBackupMonitoringUsecase(
            monitoring,
            OpenKeyServerUsecase(metadata, sessions),
          ),
        );
      }
      return RecoverBullRuntime._(
        storage,
        vaults,
        wallets,
        StartVaultFlowUsecase(wallets, environment),
        drive,
        files,
        sessions,
        metadata,
        monitoring,
        unavailable,
        coldStart,
      );
    } catch (_) {
      try {
        drive.dispose();
      } finally {
        await storage.dispose();
      }
      rethrow;
    }
  }

  ReadBackupStatusUsecase get readStatus =>
      ReadBackupStatusUsecase(_metadata, unavailable);

  CheckBackupServerUsecase get checkServer {
    final metadata = _metadata;
    return CheckBackupServerUsecase(
      metadata == null ? null : OpenKeyServerUsecase(metadata, _sessions),
      metadata,
      unavailable,
    );
  }

  BackupMonitoringCubit? monitoringPresenter() {
    final monitoring = _monitoring;
    return monitoring == null
        ? null
        : BackupMonitoringCubit(
            WatchBackupMonitoringUsecase(monitoring),
            AcknowledgeBackupAlertsUsecase(monitoring),
          );
  }

  ParseVaultUsecase get parseVault => ParseVaultUsecase(_vaults);
  ManageBackupSettingsUsecase get settings =>
      ManageBackupSettingsUsecase(_metadata, unavailable);
  RecoverServerVaultUsecase get recoverServerVault => RecoverServerVaultUsecase(
    _startFlow,
    (context) => _operations(context).session,
    unavailable,
  );

  ({ManageVaultSessionUsecase? session, CompleteVaultUsecase complete})
  _operations(VaultFlowContext captured) {
    final wallets = CapturedRecoverBullWalletPort(_wallets, captured);
    final metadata = _metadata;
    final monitoring = _monitoring;
    final complete = CompleteVaultUsecase(
      TestVaultUsecase(_vaults, wallets),
      RestoreVaultUsecase(_vaults, wallets),
      metadata,
      monitoring,
      unavailableFailure: unavailable,
    );
    ManageVaultSessionUsecase? session;
    if (metadata != null && monitoring != null) {
      final fetch = FetchVaultKeyUsecase(monitoring);
      session = ManageVaultSessionUsecase(
        metadata,
        OpenKeyServerUsecase(metadata, _sessions),
        fetch,
        CreateAndStoreVaultUsecase(
          CreateVaultUsecase(_vaults, wallets),
          SaveVaultUsecase(_files, _drive),
          metadata,
          monitoring,
          fetch,
        ),
        complete,
      );
    }
    return (session: session, complete: complete);
  }

  Future<VaultFlowPresentation> flow(
    RecoverBullFlow kind, {
    EncryptedVault? vault,
  }) async {
    final captured = await _startFlow.execute(kind);
    final operations = _operations(captured);
    final metadata = _metadata;
    final monitoring = _monitoring;
    return VaultFlowPresentation(
      VaultFlowCubit(
        ManageBackupSettingsUsecase(metadata, unavailable),
        (
          pick: PickVaultUsecase(_files),
          list: ListDriveVaultsUsecase(_drive),
          select: ReadDriveVaultUsecase(_drive),
          delete: DeleteDriveVaultUsecase(_drive),
          export: ExportDriveVaultUsecase(_files, _drive),
        ),
        operations.session,
        operations.complete,
        unavailable: unavailable,
        vault: vault,
      ),
      captured.network,
      monitoring == null
          ? null
          : BackupMonitoringCubit(
              WatchBackupMonitoringUsecase(monitoring),
              AcknowledgeBackupAlertsUsecase(monitoring),
            ),
    );
  }

  Future<void> dispose() async {
    try {
      _drive.dispose();
    } finally {
      await _storage.dispose();
    }
  }
}
