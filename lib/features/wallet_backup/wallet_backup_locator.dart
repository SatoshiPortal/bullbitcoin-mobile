import 'package:bb_mobile/features/wallet_backup/data/backup_server_http_transport.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/file_picker_wallet_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_codec_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_backup_remote_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_inventory_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_metadata_backup_repository_impl.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_codec_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_inventory_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/apply_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/build_wallet_backup_snapshot_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/compare_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/delete_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/inspect_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_files_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_wallet_backup_state_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/manage_bullvault_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/publish_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_file_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/usecases/recover_wallet_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_operation_queue.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_server_config.dart';
import 'package:bb_mobile/features/wallet_backup/watchers/wallet_backup_watcher.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';

abstract final class WalletBackupLocator {
  static void setup(GetIt locator) {
    final origin = Uri.parse(walletBackupDefaultServerUrl);
    final http = Dio();
    locator.registerLazySingleton<BackupServerHttpTransport>(
      () => BackupServerHttpTransport(dio: http, origin: origin),
      dispose: (_) => http.close(force: true),
    );
    locator.registerLazySingleton<WalletBackupRemoteRepository>(
      () => WalletBackupRemoteRepositoryImpl(locator()),
    );
    locator.registerLazySingleton<WalletBackupStateRepository>(
      () => DriftWalletBackupStateRepository(locator()),
    );
    locator.registerLazySingleton<WalletBackupCodecRepository>(
      () => WalletBackupCodecRepositoryImpl(
        vaults: locator(),
        database: locator(),
        manifest: locator(),
        metadata: locator(),
        inventory: locator(),
        wallets: locator(),
        bip85: locator(),
      ),
    );
    locator.registerLazySingleton<WalletBackupFileRepository>(
      () => FilePickerWalletBackupRepository(FilePicker.platform),
    );
    locator.registerLazySingleton<WalletMetadataBackupRepository>(
      () => WalletMetadataBackupRepositoryImpl(
        database: locator(),
        labels: locator(),
        frozen: locator(),
        settings: locator(),
        settingsWriter: locator(),
        autoSwap: locator(),
        payjoin: locator(),
        electrumServers: locator(),
        electrumSettings: locator(),
        mempoolServers: locator(),
        mempoolSettings: locator(),
      ),
    );
    locator.registerLazySingleton<WalletInventoryBackupRepository>(
      () => WalletInventoryBackupRepositoryImpl(
        database: locator(),
        wallets: locator(),
        descriptors: locator(),
        seeds: locator(),
        vaults: locator(),
        signerDevices: locator(),
      ),
    );
    locator.registerLazySingleton(WalletBackupOperationQueue.new);
    locator.registerFactory(
      () => BuildWalletBackupSnapshotUsecase(locator(), locator()),
    );
    locator.registerFactory(() => GetWalletBackupControlUsecase(locator()));
    locator.registerFactory(
      () => GetWalletBackupStateUsecase(locator(), locator()),
    );
    locator.registerFactory(() => WatchWalletBackupStateUsecase(locator()));
    locator.registerFactory(() => WatchWalletBackupSnapshotUsecase(locator()));
    locator.registerLazySingleton(
      () => SetWalletBackupEnabledUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
      ),
    );
    locator.registerFactory(
      () => InspectWalletBackupUsecase(
        identity: locator(),
        remote: locator(),
        codec: locator(),
      ),
    );
    // Manual actions and automatic work share this owner and its lost-reply state.
    locator.registerLazySingleton(
      () => PublishWalletBackupUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
        codec: locator(),
        remote: locator(),
      ),
    );
    locator.registerFactory(
      () => ApplyWalletBackupSnapshotUsecase(
        state: locator(),
        codec: locator(),
        catalog: locator(),
        wallets: locator(),
        metadata: locator(),
      ),
    );
    locator.registerFactory(
      () => RecoverWalletBackupUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
        remote: locator(),
        codec: locator(),
        apply: locator(),
      ),
    );
    locator.registerFactory(
      () => DeleteWalletBackupUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
        remote: locator(),
      ),
    );
    locator.registerFactory(() => PickWalletBackupFileUsecase(locator()));
    locator.registerFactory(
      () => ExportWalletBackupFileUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
        codec: locator(),
        files: locator(),
      ),
    );
    locator.registerFactory(
      () =>
          DecodeWalletBackupFileUsecase(identity: locator(), codec: locator()),
    );
    locator.registerFactory(
      () => CompareWalletBackupFileUsecase(
        decode: locator(),
        inspect: locator(),
        state: locator(),
        codec: locator(),
      ),
    );
    locator.registerFactory(
      () => RecoverWalletBackupFileUsecase(
        operations: locator(),
        identity: locator(),
        state: locator(),
        remote: locator(),
        codec: locator(),
        decode: locator(),
        apply: locator(),
        recoverRemote: locator(),
      ),
    );
    locator.registerLazySingleton(
      () => WalletBackupWatcher(
        publish: locator(),
        watchSnapshot: locator(),
        watchState: locator(),
      ),
      dispose: (watcher) => watcher.dispose(),
    );
    locator.registerFactory(
      () => RestoreBullVaultBackupUsecase(
        repository: locator(),
        state: locator(),
        operations: locator(),
        inspect: locator(),
      ),
    );
    locator.registerFactory(
      () => WalletBackupFacade(
        pickFile: locator(),
        exportFile: locator(),
        compareFile: locator(),
        recoverFile: locator(),
        getControl: locator(),
        inspect: locator(),
        recover: locator(),
        recoverVaults: locator(),
        getState: locator(),
        setEnabled: locator(),
        publish: locator(),
        delete: locator(),
        capture: locator(),
        watchState: locator(),
        watcher: locator(),
      ),
    );
  }
}
