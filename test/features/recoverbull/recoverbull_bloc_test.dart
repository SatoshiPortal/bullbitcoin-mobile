import 'package:bb_mobile/core/recoverbull/domain/entity/decrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/vault_provider.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart'
    as core;
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_server_connection_usecase.dart';
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
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/tor/data/usecases/init_tor_usecase.dart';
import 'package:bb_mobile/core/tor/data/usecases/tor_status_usecase.dart';
import 'package:bb_mobile/core/tor/domain/ports/tor_config_port.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_compact_block_filters_available_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/resolve_wallet_birthday_checkpoint_usecase.dart';
import 'package:bb_mobile/features/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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

class _MockInitTor extends Mock implements InitTorUsecase {}

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockFetchLatestDrive extends Mock
    implements FetchLatestGoogleDriveVaultUsecase {}

class _MockUpdateLatest extends Mock
    implements UpdateLatestEncryptedVaultTestUsecase {}

class _MockTorStatus extends Mock implements TorStatusUsecase {}

class _MockTorConfig extends Mock implements TorConfigPort {}

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockCheckCompactBlockFiltersAvailableUsecase extends Mock
    implements CheckCompactBlockFiltersAvailableUsecase {}

class _MockResolveWalletBirthdayCheckpointUsecase extends Mock
    implements ResolveWalletBirthdayCheckpointUsecase {}

class _MockEncryptedVault extends Mock implements EncryptedVault {}

SettingsEntity _buildSettings({bool useCompactBlockFiltersByDefault = false}) {
  return SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    useCompactBlockFiltersByDefault: useCompactBlockFiltersByDefault,
  );
}

void main() {
  late _MockPickVault pickVault;
  late _MockSaveFile saveFile;
  late _MockCreateVault createVault;
  late _MockStoreKey storeKey;
  late _MockCheckConnection checkConnection;
  late _MockFetchKey fetchKey;
  late _MockDecrypt decrypt;
  late _MockRestore restore;
  late _MockConnectDrive connectDrive;
  late _MockSaveDrive saveDrive;
  late _MockInitTor initTor;
  late _MockWalletBloc walletBloc;
  late _MockFetchLatestDrive fetchLatestDrive;
  late _MockUpdateLatest updateLatest;
  late _MockTorStatus torStatus;
  late _MockTorConfig torConfig;
  late _MockGetSettingsUsecase getSettings;
  late _MockCheckCompactBlockFiltersAvailableUsecase
  checkCompactBlockFiltersAvailable;
  late _MockResolveWalletBirthdayCheckpointUsecase
  resolveWalletBirthdayCheckpoint;

  setUpAll(() {
    registerFallbackValue(_MockEncryptedVault());
    registerFallbackValue(WalletBirthdayLookupMode.recovery);
    registerFallbackValue(DecryptedVault(mnemonic: const ['abandon']));
  });

  setUp(() {
    pickVault = _MockPickVault();
    saveFile = _MockSaveFile();
    createVault = _MockCreateVault();
    storeKey = _MockStoreKey();
    checkConnection = _MockCheckConnection();
    fetchKey = _MockFetchKey();
    decrypt = _MockDecrypt();
    restore = _MockRestore();
    connectDrive = _MockConnectDrive();
    saveDrive = _MockSaveDrive();
    initTor = _MockInitTor();
    walletBloc = _MockWalletBloc();
    fetchLatestDrive = _MockFetchLatestDrive();
    updateLatest = _MockUpdateLatest();
    torStatus = _MockTorStatus();
    torConfig = _MockTorConfig();
    getSettings = _MockGetSettingsUsecase();
    checkCompactBlockFiltersAvailable =
        _MockCheckCompactBlockFiltersAvailableUsecase();
    resolveWalletBirthdayCheckpoint =
        _MockResolveWalletBirthdayCheckpointUsecase();
    // None of the existing tests below exercise the `recoverVault` vault
    // decryption path (the only place these are consulted — see
    // `RecoverBullBloc._onVaultDecryption`), but the constructor still
    // requires them; default to the gate being off.
    when(() => getSettings.execute()).thenAnswer((_) async => _buildSettings());
  });

  // The bloc constructor does not auto-dispatch any event, so unstubbed mocks
  // stay untouched unless a test drives the matching flow.
  RecoverBullBloc buildBloc({
    required RecoverBullFlow flow,
    EncryptedVault? preSelectedVault,
  }) => RecoverBullBloc(
    flow: flow,
    preSelectedVault: preSelectedVault,
    pickVaultUsecase: pickVault,
    saveFileToSystemUsecase: saveFile,
    createEncryptedVaultUsecase: createVault,
    storeVaultKeyIntoServerUsecase: storeKey,
    checkKeyServerConnectionUsecase: checkConnection,
    fetchVaultKeyFromServerUsecase: fetchKey,
    decryptVaultUsecase: decrypt,
    restoreVaultUsecase: restore,
    connectToGoogleDriveUsecase: connectDrive,
    saveToGoogleDriveUsecase: saveDrive,
    initializeTorUsecase: initTor,
    walletBloc: walletBloc,
    fetchLatestGoogleDriveVaultUsecase: fetchLatestDrive,
    updateLatestEncryptedVaultTestUsecase: updateLatest,
    torStatusUsecase: torStatus,
    torConfigPort: torConfig,
    getSettingsUsecase: getSettings,
    checkCompactBlockFiltersAvailableUsecase: checkCompactBlockFiltersAvailable,
    resolveWalletBirthdayCheckpointUsecase: resolveWalletBirthdayCheckpoint,
  );

  group('OnVaultPasswordSet guard', () {
    test('no vault set -> VaultNotSetFailure, password not stored, key never '
        'fetched', () async {
      // recoverVault hits the default branch; no preSelectedVault => null.
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<VaultNotSetFailure>());
      // The guard must return before storing the password or fetching the
      // key — proving the early `return` is effective (the pre-fix code fell
      // through to `state.vault!`).
      expect(bloc.state.vaultPassword, isNull);
      verifyNever(
        () => fetchKey.execute(
          vault: any(named: 'vault'),
          password: any(named: 'password'),
        ),
      );

      await bloc.close();
    });
  });

  group('OnVaultProviderSelection (secureVault) guard', () {
    test(
      'no password set -> PasswordNotSetFailure, creation never started',
      () async {
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The pre-fix code fell through to `state.vaultPassword!`, which threw and
        // surfaced as a generic RecoverBullUnexpectedFailure. The guard must keep
        // the intended typed failure and never reach vault creation.
        expect(bloc.state.failure, isA<PasswordNotSetFailure>());
        verifyNever(() => createVault.execute());

        await bloc.close();
      },
    );
  });

  group('OnVaultCreation store-key failure mapping', () {
    test(
      'rate-limited storeVaultKey -> VaultRateLimitedFailure (cooldown kept)',
      () async {
        const cooldown = Duration(minutes: 5);
        final vault = _MockEncryptedVault();
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');

        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'deadbeef')));
        when(() => checkConnection.execute()).thenAnswer((_) async => true);
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(
            password: any(named: 'password'),
            vault: any(named: 'vault'),
            vaultKey: any(named: 'vaultKey'),
          ),
        ).thenAnswer(
          (_) async =>
              Err(const core.KeyServerRateLimitedFailure(retryIn: cooldown)),
        );

        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        // secureVault stores the password, then provider selection triggers
        // creation.
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The 429 cooldown must survive the create path instead of collapsing
        // into the generic VaultCreationFailure.
        expect(bloc.state.failure, isA<VaultRateLimitedFailure>());
        expect(
          (bloc.state.failure as VaultRateLimitedFailure).retryIn,
          cooldown,
        );

        await bloc.close();
      },
    );
  });

  group('CBF birthday picker (recoverVault flow)', () {
    final decryptedVault = DecryptedVault(mnemonic: const ['abandon']);
    final fakeCheckpoint = WalletBirthdayCheckpoint(
      requestedBirthday: DateTime.utc(2020),
      blockTimestamp: DateTime.utc(2020),
      blockHeight: 600000,
      blockHash: 'a' * 64,
    );

    setUp(() {
      when(
        () => decrypt.execute(
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      ).thenReturn(Ok(decryptedVault));
      when(
        () =>
            updateLatest.execute(decryptedVault: any(named: 'decryptedVault')),
      ).thenAnswer((_) async => const Ok(null));
    });

    test('the preference on and CBF available pauses on '
        'needsBitcoinBirthdaySelection — RestoreVaultUsecase is never called '
        'yet', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);

      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      bloc.add(const OnVaultDecryption(vaultKey: 'key'));
      await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

      expect(bloc.state.decryptedVault, decryptedVault);
      verifyNever(
        () => restore.execute(
          decryptedVault: any(named: 'decryptedVault'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      );

      await bloc.close();
    });

    test('the preference off restores and starts immediately, exactly as '
        'before this feature existed', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: false),
      );
      when(
        () => restore.execute(
          decryptedVault: any(named: 'decryptedVault'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      bloc.add(const OnVaultDecryption(vaultKey: 'key'));
      await bloc.stream.firstWhere((s) => s.isFlowFinished);

      expect(bloc.state.needsBitcoinBirthdaySelection, isFalse);
      verify(
        () => restore.execute(
          decryptedVault: decryptedVault,
          bitcoinBirthdayCheckpoint: null,
        ),
      ).called(1);
      verify(() => walletBloc.add(const WalletStarted())).called(1);
      verifyNever(() => checkCompactBlockFiltersAvailable.execute());

      await bloc.close();
    });

    test('resolveBitcoinBirthdayCheckpoint always resolves with '
        'WalletBirthdayLookupMode.recovery', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);
      when(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: any(named: 'requestedBirthday'),
          isTestnet: any(named: 'isTestnet'),
          lookupMode: any(named: 'lookupMode'),
        ),
      ).thenAnswer((_) async => Ok(fakeCheckpoint));

      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      bloc.add(const OnVaultDecryption(vaultKey: 'key'));
      await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

      final requestedBirthday = DateTime.utc(2015);
      final result = await bloc.resolveBitcoinBirthdayCheckpoint(
        requestedBirthday,
      );

      expect(result, isA<Ok<WalletBirthdayCheckpoint, dynamic>>());
      verify(
        () => resolveWalletBirthdayCheckpoint.execute(
          requestedBirthday: requestedBirthday,
          isTestnet: false,
          lookupMode: WalletBirthdayLookupMode.recovery,
        ),
      ).called(1);

      await bloc.close();
    });

    test('OnBitcoinBirthdayResolved with a checkpoint resumes restore, passing '
        'it through to RestoreVaultUsecase, and starts the real WalletBloc '
        'sync on success', () async {
      when(() => getSettings.execute()).thenAnswer(
        (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
      );
      when(
        () => checkCompactBlockFiltersAvailable.execute(),
      ).thenAnswer((_) async => true);

      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
      bloc.add(const OnVaultDecryption(vaultKey: 'key'));
      await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

      when(
        () => restore.execute(
          decryptedVault: any(named: 'decryptedVault'),
          bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
        ),
      ).thenAnswer((_) async => const Ok(null));

      bloc.add(OnBitcoinBirthdayResolved(checkpoint: fakeCheckpoint));
      await bloc.stream.firstWhere((s) => s.isFlowFinished);

      verify(
        () => restore.execute(
          decryptedVault: decryptedVault,
          bitcoinBirthdayCheckpoint: fakeCheckpoint,
        ),
      ).called(1);
      verify(() => walletBloc.add(const WalletStarted())).called(1);

      await bloc.close();
    });

    test(
      'OnBitcoinBirthdayResolved with no checkpoint (user backed out of the '
      'picker) aborts — no wallet is ever restored, never a partial pair',
      () async {
        when(() => getSettings.execute()).thenAnswer(
          (_) async => _buildSettings(useCompactBlockFiltersByDefault: true),
        );
        when(
          () => checkCompactBlockFiltersAvailable.execute(),
        ).thenAnswer((_) async => true);

        final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);
        bloc.add(const OnVaultDecryption(vaultKey: 'key'));
        await bloc.stream.firstWhere((s) => s.needsBitcoinBirthdaySelection);

        bloc.add(const OnBitcoinBirthdayResolved());
        await bloc.stream.firstWhere((s) => !s.needsBitcoinBirthdaySelection);

        expect(bloc.state.isFlowFinished, isFalse);
        verifyNever(
          () => restore.execute(
            decryptedVault: any(named: 'decryptedVault'),
            bitcoinBirthdayCheckpoint: any(named: 'bitcoinBirthdayCheckpoint'),
          ),
        );
        verifyNever(() => walletBloc.add(const WalletStarted()));

        await bloc.close();
      },
    );
  });
}
