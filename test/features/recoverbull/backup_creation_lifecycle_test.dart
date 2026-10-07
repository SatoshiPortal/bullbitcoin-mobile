import 'package:bb_mobile/features/recoverbull/domain/usecases/record_encrypted_backup_creation_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/repositories/recoverbull_repository.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/presentation/cubit/backup_settings_cubit.dart';
import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/create_encrypted_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/decrypt_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/connect_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/fetch_latest_google_drive_backup_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/google_drive/save_to_google_drive_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/pick_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/restore_vault_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/save_file_to_system_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/store_vault_key_into_server_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/update_latest_encrypted_backup_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/recoverbull/domain/usecases/connect_to_key_server_usecase.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockPickVault extends Mock implements PickVaultUsecase {}

class _MockSaveFile extends Mock implements SaveFileToSystemUsecase {}

class _MockCreateVault extends Mock implements CreateEncryptedVaultUsecase {}

class _MockStoreKey extends Mock implements StoreVaultKeyIntoServerUsecase {}

class _MockCheckConnection extends Mock
    implements CheckServerConnectionUsecase {}

class _MockFetchKey extends Mock implements FetchVaultKeyFromServerUsecase {}

class _MockDecrypt extends Mock implements DecryptVaultUsecase {}

class _MockRestore extends Mock implements RestoreVaultUsecase {}

class _MockConnectDrive extends Mock implements ConnectToGoogleDriveUsecase {}

class _MockSaveDrive extends Mock implements SaveVaultToGoogleDriveUsecase {}

class _MockEnsureRecoverBullTorSession extends Mock
    implements EnsureRecoverBullTorSessionUsecase {}

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockFetchLatestDrive extends Mock
    implements FetchLatestGoogleDriveVaultUsecase {}

class _MockUpdateLatest extends Mock
    implements UpdateLatestEncryptedVaultTestUsecase {}

class _MockWatchTorConnection extends Mock
    implements WatchTorConnectionUsecase {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSeedRepository extends Mock implements SeedRepository {}

class _MockRecoverRepository extends Mock implements RecoverBullRepository {}

class _MockWallet extends Mock implements Wallet {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

void main() {
  late _MockPickVault pickVault;
  late _MockSaveFile saveFile;
  late CreateEncryptedVaultUsecase createVault;
  late RecordEncryptedBackupCreationUsecase recordCreation;
  late _MockStoreKey storeKey;
  late _MockCheckConnection checkConnection;
  late _MockFetchKey fetchKey;
  late _MockDecrypt decrypt;
  late _MockRestore restore;
  late _MockConnectDrive connectDrive;
  late _MockSaveDrive saveDrive;
  late _MockEnsureRecoverBullTorSession ensureRecoverBullTorSession;
  late _MockWalletBloc walletBloc;
  late _MockFetchLatestDrive fetchLatestDrive;
  late _MockUpdateLatest updateLatest;
  late _MockWatchTorConnection watchTor;

  setUpAll(() {
    registerFallbackValue(_MockEncryptedVault());
  });

  setUp(() {
    pickVault = _MockPickVault();
    saveFile = _MockSaveFile();
    createVault = _MockCreateVault();
    storeKey = _MockStoreKey();
    checkConnection = _MockCheckConnection();
    when(
      () => checkConnection.execute(),
    ).thenAnswer((_) async => const Ok(true));
    fetchKey = _MockFetchKey();
    decrypt = _MockDecrypt();
    restore = _MockRestore();
    connectDrive = _MockConnectDrive();
    saveDrive = _MockSaveDrive();
    ensureRecoverBullTorSession = _MockEnsureRecoverBullTorSession();
    when(
      () => ensureRecoverBullTorSession.execute(
        restartEmbedded: any(named: 'restartEmbedded'),
      ),
    ).thenAnswer((_) async => const Err(core.KeyServerUnavailableFailure()));
    walletBloc = _MockWalletBloc();
    fetchLatestDrive = _MockFetchLatestDrive();
    updateLatest = _MockUpdateLatest();
    watchTor = _MockWatchTorConnection();
    when(
      () => watchTor.execute(),
    ).thenAnswer((_) => const Stream<TorConnectionState>.empty());
  });

  // No event is auto-dispatched, so unstubbed mocks stay untouched unless a
  // test drives the matching flow — the Tor subscription above excepted.
  RecoverBullBloc buildBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
  }) => RecoverBullBloc(
    flow: flow,
    preSelectedVault: preSelectedVault,
    pickVaultUsecase: pickVault,
    saveFileToSystemUsecase: saveFile,
    createEncryptedVaultUsecase: createVault,
    recordEncryptedBackupCreationUsecase: recordCreation,
    storeVaultKeyIntoServerUsecase: storeKey,
    checkKeyServerConnectionUsecase: checkConnection,
    connectToKeyServerUsecase: ConnectToKeyServerUsecase(
      checkConnection,
      ensureRecoverBullTorSession,
      wait: (_) async {},
    ),
    fetchVaultKeyFromServerUsecase: fetchKey,
    decryptVaultUsecase: decrypt,
    restoreVaultUsecase: restore,
    connectToGoogleDriveUsecase: connectDrive,
    saveToGoogleDriveUsecase: saveDrive,
    ensureRecoverBullTorSessionUsecase: ensureRecoverBullTorSession,
    walletBloc: walletBloc,
    fetchLatestGoogleDriveVaultUsecase: fetchLatestDrive,
    updateLatestEncryptedVaultTestUsecase: updateLatest,
    watchTorConnectionUsecase: watchTor,
  );

  for (final scenario in [
    'first local success',
    'first drive success',
    'repeated local success',
    'connection failure',
    'file failure',
    'drive connection failure',
    'drive save failure',
    'server failure',
    'metadata failure',
    'metadata failure with previous vault',
    'unsupported provider',
  ]) {
    test('creation metadata: $scenario', () async {
      final successful = scenario.endsWith('success');
      final first = scenario.startsWith('first');
      final provider = scenario.contains('drive')
          ? VaultProvider.googleDrive
          : scenario == 'unsupported provider'
          ? VaultProvider.iCloud
          : VaultProvider.customLocation;
      final oldDate = first ? null : DateTime.utc(2026, 1, 1);
      DateTime? persistedBackupDate = oldDate;
      var persistedVerified = !first;
      var fileSaved = false;
      var keyStored = false;
      final wallets = _MockWalletRepository();
      final seeds = _MockSeedRepository();
      final recover = _MockRecoverRepository();
      final wallet = _MockWallet();
      final settingsRepository = _MockSettingsRepository();
      final settings = _MockSettings();
      final seed = SeedModel.mnemonic(
        mnemonicWords: [...List.filled(11, 'zoo'), 'wrong'],
      ).toEntity();
      when(() => wallet.id).thenReturn('source-wallet');
      when(() => wallet.masterFingerprint).thenReturn(seed.masterFingerprint);
      when(() => wallet.network).thenReturn(Network.bitcoinMainnet);
      when(
        () => wallet.isEncryptedVaultTested,
      ).thenAnswer((_) => persistedVerified);
      when(() => wallet.isPhysicalBackupTested).thenReturn(false);
      when(
        () => wallet.latestEncryptedBackup,
      ).thenAnswer((_) => persistedBackupDate);
      when(() => wallet.latestPhysicalBackup).thenReturn(null);
      when(
        () => wallets.getWallets(
          onlyBitcoin: any(named: 'onlyBitcoin'),
          onlyDefaults: any(named: 'onlyDefaults'),
          onlyLiquid: any(named: 'onlyLiquid'),
          environment: any(named: 'environment'),
          sync: any(named: 'sync'),
        ),
      ).thenAnswer((_) async => Ok([wallet]));
      when(
        () => wallets.recordEncryptedBackupCreation(
          time: any(named: 'time'),
          walletId: 'source-wallet',
        ),
      ).thenAnswer((invocation) async {
        expect(fileSaved, isTrue);
        expect(keyStored, isTrue);
        if (scenario.startsWith('metadata failure')) {
          throw StateError('Storage unavailable');
        }
        persistedBackupDate = invocation.namedArguments[#time] as DateTime;
        persistedVerified = false;
      });
      when(
        () => seeds.get(seed.masterFingerprint),
      ).thenAnswer((_) async => seed);
      final vault = _MockEncryptedVault();
      when(() => vault.toFile()).thenReturn('{}');
      when(() => vault.filename).thenReturn('public-test-vault.json');
      when(
        () => recover.createVault(
          vaultKey: any(named: 'vaultKey'),
          plaintext: any(named: 'plaintext'),
          derivationPath: any(named: 'derivationPath'),
        ),
      ).thenReturn(Ok(vault));
      createVault = CreateEncryptedVaultUsecase(
        recoverBullRepository: recover,
        seedRepository: seeds,
        walletRepository: wallets,
      );
      recordCreation = RecordEncryptedBackupCreationUsecase(wallets);
      when(
        () => checkConnection.execute(),
      ).thenAnswer((_) async => Ok(scenario != 'connection failure'));
      when(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((_) async {
        expect(persistedBackupDate, oldDate);
        expect(persistedVerified, !first);
        if (scenario == 'file failure') {
          return const Err(
            core.RecoverBullUnexpectedCoreFailure('Save cancelled'),
          );
        }
        fileSaved = true;
        return const Ok(null);
      });
      when(() => connectDrive.execute()).thenAnswer(
        (_) async => scenario == 'drive connection failure'
            ? const Err(
                core.RecoverBullUnexpectedCoreFailure('Drive unavailable'),
              )
            : const Ok(null),
      );
      when(() => saveDrive.execute(vault)).thenAnswer((_) async {
        expect(persistedBackupDate, oldDate);
        if (scenario == 'drive save failure') {
          return const Err(
            core.RecoverBullUnexpectedCoreFailure('Drive save failed'),
          );
        }
        fileSaved = true;
        return const Ok(null);
      });
      when(
        () => storeKey.execute(
          password: any(named: 'password'),
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      ).thenAnswer((_) async {
        expect(fileSaved, isTrue);
        expect(persistedBackupDate, oldDate);
        expect(persistedVerified, !first);
        if (scenario == 'server failure') {
          return const Err(core.KeyServerUnavailableFailure());
        }
        keyStored = true;
        return const Ok(null);
      });
      final bloc = buildBloc(
        flow: RecoverBullFlow.secureVault,
        preSelectedVault: scenario.endsWith('previous vault')
            ? _MockEncryptedVault()
            : null,
      );
      addTearDown(bloc.close);
      final started = DateTime.now();
      bloc.add(
        OnVaultCreation(provider: provider, password: 'public-test-password'),
      );
      await pumpEventQueue();
      expect(bloc.state.isLoading, isFalse);
      if (successful) {
        expect(bloc.state.failure, isNull);
        expect(bloc.state.vault, same(vault));
        expect(persistedBackupDate, isNotNull);
        expect(persistedBackupDate!.isBefore(started), isFalse);
        expect(persistedVerified, isFalse);
      } else {
        expect(bloc.state.failure, isNotNull);
        expect(bloc.state.vault, isNull);
        expect(persistedBackupDate, oldDate);
        expect(persistedVerified, !first);
      }
      if (successful || scenario.startsWith('metadata failure')) {
        verify(
          () => wallets.recordEncryptedBackupCreation(
            time: any(named: 'time'),
            walletId: 'source-wallet',
          ),
        ).called(1);
      } else {
        verifyNever(
          () => wallets.recordEncryptedBackupCreation(
            time: any(named: 'time'),
            walletId: any(named: 'walletId'),
          ),
        );
      }
      when(() => settings.environment).thenReturn(Environment.mainnet);
      when(settingsRepository.fetch).thenAnswer((_) async => settings);
      final backupSettings = BackupSettingsCubit(
        getWalletsUsecase: GetWalletsUsecase(
          walletRepository: wallets,
          settingsRepository: settingsRepository,
        ),
        settingsRepository: settingsRepository,
      );
      addTearDown(backupSettings.close);
      await backupSettings.checkBackupStatus();
      expect(backupSettings.state.status, BackupSettingsStatus.success);
      expect(backupSettings.state.lastEncryptedBackup, persistedBackupDate);
      expect(
        backupSettings.state.isDefaultEncryptedBackupTested,
        persistedVerified,
      );
      if (successful) {
        expect(backupSettings.state.lastEncryptedBackup, isNotNull);
      }
    });
  }
}
