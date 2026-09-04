import 'dart:async';
import 'dart:io';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_lifecycle_port.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/usecases/check_server_connection_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/verify_decrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/pick_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:primitives/primitives.dart';
import 'log_sink.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';

class MockPickVault extends Mock implements PickVaultUsecase {}

class MockSaveFile extends Mock implements SaveFileToSystemUsecase {}

class MockCreateVault extends Mock implements CreateEncryptedVaultUsecase {}

class MockStoreKey extends Mock implements StoreVaultKeyIntoServerUsecase {}

class MockCheckConnection extends Mock
    implements CheckServerConnectionUsecase {}

class MockFetchKey extends Mock implements FetchVaultKeyFromServerUsecase {}

class MockDecrypt extends Mock implements DecryptVaultUsecase {}

class MockRestore extends Mock implements RestoreVaultUsecase {}

class MockConnectDrive extends Mock implements ConnectToGoogleDriveUsecase {}

class MockSaveDrive extends Mock implements SaveVaultToGoogleDriveUsecase {}

class MockEnsureRecoverBullTorSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

class MockFetchLatestDrive extends Mock
    implements FetchLatestGoogleDriveVaultUsecase {}

class MockWatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}

class MockLifecycle extends Mock implements RecoverBullLifecyclePort {}

class MockVerifyVault extends Mock implements VerifyDecryptedVaultUsecase {}

class MockEncryptedVault extends Mock implements EncryptedVault {}

RecoverBullTorRoute testRoute({Future<void> Function()? onClose}) =>
    RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      onClose ?? () async {},
      HttpClient(),
    );

MockPickVault pickVault = MockPickVault();
MockSaveFile saveFile = MockSaveFile();
MockCreateVault createVault = MockCreateVault();
MockStoreKey storeKey = MockStoreKey();
MockCheckConnection checkConnection = MockCheckConnection();
MockFetchKey fetchKey = MockFetchKey();
MockDecrypt decrypt = MockDecrypt();
MockRestore restore = MockRestore();
MockConnectDrive connectDrive = MockConnectDrive();
MockSaveDrive saveDrive = MockSaveDrive();
MockEnsureRecoverBullTorSession ensureRecoverBullTorSession =
    MockEnsureRecoverBullTorSession();
MockFetchLatestDrive fetchLatestDrive = MockFetchLatestDrive();
MockWatchTorConnection watchTor = MockWatchTorConnection();
MockLifecycle lifecycle = MockLifecycle();
MockVerifyVault verifyVault = MockVerifyVault();
late RecoverBullDatabase database;
late RecoverBullAttemptMonitoringStore attemptMonitoringStore;

Future<void> setUpRecoverBullBloc() async {
  database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
  await database.ensureState();
  attemptMonitoringStore = RecoverBullAttemptMonitoringStore(database);
  pickVault = MockPickVault();
  saveFile = MockSaveFile();
  createVault = MockCreateVault();
  storeKey = MockStoreKey();
  checkConnection = MockCheckConnection();
  when(() => checkConnection.execute()).thenAnswer((_) async => const Ok(true));
  fetchKey = MockFetchKey();
  decrypt = MockDecrypt();
  restore = MockRestore();
  connectDrive = MockConnectDrive();
  saveDrive = MockSaveDrive();
  ensureRecoverBullTorSession = MockEnsureRecoverBullTorSession();
  when(
    () => ensureRecoverBullTorSession.execute(
      restartEmbedded: any(named: 'restartEmbedded'),
    ),
  ).thenAnswer((_) async => const Err(core.KeyServerUnavailableFailure()));
  fetchLatestDrive = MockFetchLatestDrive();
  watchTor = MockWatchTorConnection();
  lifecycle = MockLifecycle();
  verifyVault = MockVerifyVault();
  when(
    () => verifyVault.execute(decryptedVault: any(named: 'decryptedVault')),
  ).thenAnswer((_) async => const Ok(VaultVerificationResult.match));
  when(() => lifecycle.markStored()).thenAnswer((_) async {});
  when(() => lifecycle.markVerified()).thenAnswer((_) async {});
  when(
    () => watchTor.execute(),
  ).thenAnswer((_) => const Stream<TorConnectionState>.empty());
}

Future<void> tearDownRecoverBullBloc() => database.close();

RecoverBullBloc buildBloc({
  required RecoverBullFlow flow,
  EncryptedVault? preSelectedVault,
  Future<void> Function()? onWalletUpdated,
  VerifyDecryptedVaultUsecase? verifyDecryptedVaultUsecase,
}) => RecoverBullBloc(
  log: const TestLogSink(),
  flow: flow,
  preSelectedVault: preSelectedVault,
  pickVaultUsecase: pickVault,
  saveFileToSystemUsecase: saveFile,
  createEncryptedVaultUsecase: createVault,
  storeVaultKeyIntoServerUsecase: storeKey,
  registerMonitoredBackupUsecase: RegisterMonitoredBackupUsecase(
    attemptMonitoringStore,
  ),
  checkKeyServerConnectionUsecase: checkConnection,
  connectToKeyServerUsecase: ConnectToKeyServerUsecase(
    check: checkConnection,
    ensureTor: ensureRecoverBullTorSession,
    log: const TestLogSink(),
    wait: (_) async {},
  ),
  fetchVaultKeyFromServerUsecase: fetchKey,
  decryptVaultUsecase: decrypt,
  restoreVaultUsecase: restore,
  connectToGoogleDriveUsecase: connectDrive,
  saveToGoogleDriveUsecase: saveDrive,
  ensureRecoverBullTorSessionUsecase: ensureRecoverBullTorSession,
  onWalletUpdated: onWalletUpdated,
  fetchLatestGoogleDriveVaultUsecase: fetchLatestDrive,
  watchTorConnectionUsecase: watchTor,
  lifecycle: lifecycle,
  verifyDecryptedVaultUsecase: verifyDecryptedVaultUsecase ?? verifyVault,
);
