import 'dart:async';

import 'package:bb_mobile/features/send/domain/usecases/recognize_ark_address_usecase.dart';
import 'package:bull_ark/bull_ark.dart'
    show ArkAddressRoutingFacade, ArkFeatureStorageFailure;
import 'package:bb_mobile/features/send/presentation/send_ark_cubit.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:ark/ark.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bb_mobile/features/wallet/public/ark_funding_setup.dart';
import 'package:bb_mobile/features/wallet/public/ark_foreground_setup.dart';
import 'package:bb_mobile/features/wallet/domain/seed_reference_port.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

import 'features/wallet/data/ark_funding_test_fixture.dart';

import 'package:primitives/primitives.dart';
import 'package:drift/drift.dart' show Value;
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart'
    show ElectrumFailure, ElectrumSaveFailure, RegtestElectrumProfile;

import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/wallet/data/sync_coordinator.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/sp/watchers/sp_electrum_reconnect_watcher.dart';
import 'package:bb_mobile/features/sp/watchers/sp_tip_watcher.dart';
import 'package:bb_mobile/locator.dart';
import 'package:drift/native.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secrets/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RoutingPreferences implements ArkPreferencesRepository {
  bool enabled = true;
  Future<Result<bool, ArkFailure>> Function(ArkAccountId)? read;

  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async {
    final reader = read;
    return reader == null ? Ok(enabled) : reader(account);
  }

  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool enabled,
  ) async => const Ok(null);
}

class _SecureStorage extends FakeSecureStoragePlatform {
  final Fingerprint parent;
  int parentDeletes = 0;
  _SecureStorage(this.parent);

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) {
    if (key == 'seed_${parent.hex}') parentDeletes++;
    return super.delete(key: key, options: options);
  }
}

class _Paths extends PathProviderPlatform {
  final String path;

  _Paths(this.path);

  @override
  Future<String> getApplicationDocumentsPath() async => path;
  @override
  Future<String> getTemporaryPath() async => path;
  @override
  Future<String> getApplicationSupportPath() async => path;
}

class _NativeTor implements TorNativeInitializer {
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile-independent Ark custody at restart', () {
    late Directory directory;
    late GetIt locator;
    late SqliteDatabase database;
    late PathProviderPlatform previousPaths;
    SharedPreferencesAsyncPlatform? previousPreferences;
    var composed = false;
    final parent = Fingerprint('00112233');
    setUp(() async {
      composed = false;
      directory = await Directory.systemTemp.createTemp('ark-root-custody-');
      previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FakeSecureStoragePlatform().install();
      SharedPreferences.setMockInitialValues({});
      previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      database = SqliteDatabase(NativeDatabase.memory());
      locator = GetIt.asNewInstance();
      locator.registerSingleton<TorNativeInitializer>(_NativeTor());
    });
    tearDown(() async {
      if (composed) {
        await locator<SpTipWatcher>().dispose();
        await locator<SpElectrumReconnectWatcher>().dispose();
        locator<SyncCoordinator>().dispose();
      }
      await locator.reset();
      await database.close();
      PathProviderPlatform.instance = previousPaths;
      SharedPreferencesAsyncPlatform.instance = previousPreferences;
      await directory.delete(recursive: true);
    });
    Future<void> compose({bool initialize = false}) async {
      expect(
        await AppLocator.setup(
          locator,
          database,
          payjoinDatabasePath: '${directory.path}/payjoin.sqlite',
          arkFundingDatabasePath: '${directory.path}/ark-funding.sqlite',
          initializeArkFunding: initialize,
          startPayjoinRecovery: false,
          startOrderSwapWatcher: false,
          startAutoswapWatcher: false,
        ),
        isA<Ok>(),
      );
      composed = true;
    }

    Future<void> publishAccount({
      int renewalThresholdBlocks = 1008,
      Uri? fallbackEsploraUrl,
    }) async {
      Directory('${directory.path}/ark').createSync();
      final registry = (SqliteArkAccountRegistry.open(
        '${directory.path}/ark/accounts.sqlite',
        foreground: true,
        initializeNew: true,
      ) as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
      try {
        expect(
          await registry.publish(
            ArkAccountConfig(
              id: ArkAccountId(
                parent: parent,
                network: BitcoinNetwork.regtest,
                serverIdentity: 'http://ark.regtest',
              ),
              arkUrl: Uri.parse('http://ark.regtest'),
              primaryEsploraUrl: Uri.parse('http://chain.regtest'),
              fallbackEsploraUrl: fallbackEsploraUrl,
              renewalThresholdBlocks: renewalThresholdBlocks,
            ),
          ),
          isA<Ok>(),
        );
      } finally {
        registry.close();
      }
    }

    Future<_RoutingPreferences> composeRouting({
      int renewalThresholdBlocks = 1008,
      Uri? fallbackEsploraUrl,
    }) async {
      await compose(initialize: true);
      await database.managers.settings.update(
        (row) => row(
          environment: const Value('regtest'),
          isSuperuser: const Value(true),
          isDevModeEnabled: const Value(true),
        ),
      );
      await locator<WalletMetadataDatasource>().insert(
        WalletMetadataModel(
          id: 'routing-source',
          networkCode: 'bitcoinRegtest',
          masterFingerprint: parent.hex,
          xpubFingerprint: '00112233',
          isEncryptedVaultTested: false,
          isPhysicalBackupTested: false,
          xpub: 'public-routing-fixture',
          externalPublicDescriptor: 'public-routing-fixture',
          internalPublicDescriptor: 'public-routing-fixture',
          signer: Signer.local,
          isDefault: true,
        ),
      );
      final preferences = _RoutingPreferences();
      await setupArkForeground(
        locator,
        arkUrl: Uri.parse('http://ark.regtest'),
        primaryEsploraUrl: Uri.parse('http://chain.regtest'),
        initializeNew: true,
        preferences: preferences,
      );
      await publishAccount(
        renewalThresholdBlocks: renewalThresholdBlocks,
        fallbackEsploraUrl: fallbackEsploraUrl,
      );
      return preferences;
    }

    Future<void> resolveArk(SendArkCubit cubit) => cubit.resolve(
      input: 'tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z',
      network: BitcoinNetwork.regtest,
      coinControl: false,
      sweep: false,
      silentPayments: false,
      multipleRecipients: false,
    );

    test(
      'cold routing cannot create a missing custody reference owner',
      () async {
        var starts = 0;
        final host = ArkForegroundHost(
          locator,
          arkUrl: Uri.parse('http://ark.regtest'),
          primaryEsploraUrl: Uri.parse('http://chain.regtest'),
          initializeNew: true,
          boardFunding: () {
            starts++;
            throw StateError('Routing must not open a runtime');
          },
        );
        addTearDown(host.close);
        expect(
          await host.listEnabledAccounts(BitcoinNetwork.regtest),
          isA<Err>(),
        );
        expect(starts, 0);
        expect(locator.isRegistered<SeedReferences>(), isFalse);
        expect(Directory('${directory.path}/ark').existsSync(), isFalse);
      },
    );

    test(
      'cold Send inventory never opens native runtime or maintenance',
      () async {
        final preferences = await composeRouting();
        var starts = 0;
        var networkCalls = 0;
        final host = ArkForegroundHost(
          locator,
          arkUrl: Uri.parse('http://ark.regtest'),
          primaryEsploraUrl: Uri.parse('http://chain.regtest'),
          initializeNew: false,
          preferences: preferences,
          boardFunding: () {
            starts++;
            throw StateError('A paste must not construct a native runtime');
          },
        );
        addTearDown(host.close);
        final cubit = SendArkCubit(
          RecognizeArkAddressUsecase.resolving(
            ArkAddressRoutingFacade(host.listEnabledAccounts),
          ),
        );
        addTearDown(cubit.close);
        await HttpOverrides.runZoned(
          () => resolveArk(cubit),
          createHttpClient: (_) {
            networkCalls++;
            throw StateError('A paste must not access the network');
          },
        );
        expect(cubit.state, isA<SendArkReady>());
        expect(starts, 0);
        expect(networkCalls, 0);
        expect(Directory('${directory.path}/ark/native').existsSync(), isFalse);
        expect(
          File('${directory.path}/ark/reminders.sqlite').existsSync(),
          isFalse,
        );
        expect(await host.homeObservation(), isNull);
      },
    );

    for (final change in ['invalidate', 'close']) {
      test(
        'cold Send refuses $change while routing preferences are pending',
        () async {
          final preferences = await composeRouting();
          final entered = Completer<void>();
          final released = Completer<void>();
          preferences.read = (_) async {
            entered.complete();
            await released.future;
            return const Ok(true);
          };
          var starts = 0;
          final host = ArkForegroundHost(
            locator,
            arkUrl: Uri.parse('http://ark.regtest'),
            primaryEsploraUrl: Uri.parse('http://chain.regtest'),
            initializeNew: false,
            preferences: preferences,
            boardFunding: () {
              starts++;
              throw StateError('A paste must not construct a native runtime');
            },
          );
          addTearDown(host.close);
          final cubit = SendArkCubit(
            RecognizeArkAddressUsecase.resolving(
              ArkAddressRoutingFacade(host.listEnabledAccounts),
            ),
          );
          addTearDown(cubit.close);
          final pending = resolveArk(cubit);
          await entered.future;
          if (change == 'invalidate') {
            host.invalidate();
          } else {
            await host.close();
          }
          released.complete();
          await pending;
          expect(cubit.state, isA<SendArkUnavailable>());
          expect(starts, 0);
          expect(
            Directory('${directory.path}/ark/native').existsSync(),
            isFalse,
          );
          expect(
            File('${directory.path}/ark/reminders.sqlite').existsSync(),
            isFalse,
          );
        },
      );
    }

    for (final mismatch in [
      'parent',
      'ark',
      'esplora',
      'fallback',
      'threshold',
    ]) {
      test(
        'cold Send refuses a published configuration with different $mismatch',
        () async {
          final preferences = await composeRouting(
            fallbackEsploraUrl: mismatch == 'fallback'
                ? Uri.parse('http://fallback.regtest')
                : null,
            renewalThresholdBlocks: mismatch == 'threshold' ? 144 : 1008,
          );
          if (mismatch == 'parent') {
            await database.managers.walletMetadatas.update(
              (row) => row(masterFingerprint: const Value('aabbccdd')),
            );
          }
          var starts = 0;
          final host = ArkForegroundHost(
            locator,
            arkUrl: Uri.parse(
              mismatch == 'ark' ? 'http://other.regtest' : 'http://ark.regtest',
            ),
            primaryEsploraUrl: Uri.parse(
              mismatch == 'esplora'
                  ? 'http://other-chain.regtest'
                  : 'http://chain.regtest',
            ),
            initializeNew: false,
            preferences: preferences,
            boardFunding: () {
              starts++;
              throw StateError('A paste must not construct a native runtime');
            },
          );
          addTearDown(host.close);
          final cubit = SendArkCubit(
            RecognizeArkAddressUsecase.resolving(
              ArkAddressRoutingFacade(host.listEnabledAccounts),
            ),
          );
          addTearDown(cubit.close);
          await resolveArk(cubit);
          expect(cubit.state, isA<SendArkUnavailable>());
          expect(starts, 0);
        },
      );
    }

    test(
      'composed Send refuses disabled and unreadable routing preferences',
      () async {
        final preferences = await composeRouting();
        final cubit = locator<SendArkCubit>();
        addTearDown(cubit.close);
        preferences.enabled = false;
        await resolveArk(cubit);
        expect(cubit.state, isA<SendArkUnavailable>());
        preferences.read = (_) async => const Err(ArkFeatureStorageFailure());
        await resolveArk(cubit);
        expect(cubit.state, isA<SendArkUnavailable>());
      },
    );

    test(
      'composed Send refuses a selection changed during local inventory',
      () async {
        final preferences = await composeRouting();
        final entered = Completer<void>();
        final released = Completer<void>();
        preferences.read = (_) async {
          entered.complete();
          await released.future;
          return const Ok(true);
        };
        final cubit = locator<SendArkCubit>();
        addTearDown(cubit.close);
        final pending = resolveArk(cubit);
        await entered.future;
        await database.managers.settings.update(
          (row) => row(environment: const Value('mainnet')),
        );
        released.complete();
        await pending;
        expect(cubit.state, isA<SendArkUnavailable>());
      },
    );

    test(
      'composed regtest Send reaches ArkReady through the current host',
      () async {
        await compose(initialize: true);
        await database.managers.settings.update(
          (row) => row(
            environment: const Value('regtest'),
            isSuperuser: const Value(true),
            isDevModeEnabled: const Value(true),
          ),
        );
        await locator<WalletMetadataDatasource>().insert(
          WalletMetadataModel(
            id: 'routing-source',
            networkCode: 'bitcoinRegtest',
            masterFingerprint: parent.hex,
            xpubFingerprint: '00112233',
            isEncryptedVaultTested: false,
            isPhysicalBackupTested: false,
            xpub: 'public-routing-fixture',
            externalPublicDescriptor: 'public-routing-fixture',
            internalPublicDescriptor: 'public-routing-fixture',
            signer: Signer.local,
            isDefault: true,
          ),
        );
        await setupArkForeground(
          locator,
          arkUrl: Uri.parse('http://ark.regtest'),
          primaryEsploraUrl: Uri.parse('http://chain.regtest'),
          initializeNew: true,
          preferences: _RoutingPreferences(),
        );
        await publishAccount();
        final cubit = locator<SendArkCubit>();
        addTearDown(cubit.close);
        Future<void> resolve() => cubit.resolve(
          input: 'tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z',
          network: BitcoinNetwork.regtest,
          coinControl: false,
          sweep: false,
          silentPayments: false,
          multipleRecipients: false,
        );
        final native = Directory('${directory.path}/ark/native');
        final reminders = File('${directory.path}/ark/reminders.sqlite');
        expect(native.existsSync(), isFalse);
        expect(reminders.existsSync(), isFalse);
        await resolve();
        expect(
          cubit.state,
          isA<SendArkReady>().having(
            (state) => state.request.accounts.single.parent,
            'current account',
            parent,
          ),
        );
        expect(native.existsSync(), isFalse);
        expect(reminders.existsSync(), isFalse);
        await database.managers.settings.update(
          (row) => row(environment: const Value('mainnet')),
        );
        await resolve();
        expect(cubit.state, isA<SendArkUnavailable>());
      },
    );

    test('profile initialization cannot recreate a lost registry over surviving custody', () async {
      final funding = sourceOk(
        SqliteArkFundingReservations.open(
          '${directory.path}/ark-funding.sqlite',
          foreground: true,
          initializeNew: true,
        ),
      );
      funding.close();
      Directory('${directory.path}/ark/native').createSync(recursive: true);
      await compose(initialize: true);
      await setupArkForeground(
        locator,
        arkUrl: Uri.parse('http://ark.regtest'),
        primaryEsploraUrl: Uri.parse('http://chain.regtest'),
        initializeNew: true,
      );
      expect(
        File('${directory.path}/ark/accounts.sqlite').existsSync(),
        isFalse,
      );
      expect(
        File('${directory.path}/ark/accounts.sqlite.initialized').existsSync(),
        isFalse,
      );
      final storage = _SecureStorage(parent)..install();
      final result = await locator<SeedReferences>().deleteUnreferenced(
        Secrets(scratchDirectory: () async => directory.path),
        parent,
      );
      expect(result, isA<Err>());
      expect(storage.parentDeletes, 0);
    });

    for (final scenario in [
      'confirmed Board',
      'receive only',
      'unreadable registry',
      'unreadable funding',
    ]) {
      test(
        '$scenario without endpoint defines cannot reach Secrets.trash',
        () async {
          await publishAccount();
          final path = '${directory.path}/ark-funding.sqlite';
          final funding = sourceOk(
            SqliteArkFundingReservations.open(
              path,
              foreground: true,
              initializeNew: true,
            ),
          );
          try {
            if (scenario == 'confirmed Board') {
              sourceOk(
                await funding.beginBoardRequest(
                  operationId: 'board',
                  accountIdentity: 'account',
                  sourceParent: parent,
                  key: fundingKey,
                  generation: 1,
                  context: 'context',
                ),
              );
              sourceOk(
                await funding.reserve(
                  key: fundingKey,
                  spend: UnsignedSpend(
                    revision: fundingStamp,
                    encoded: publicFundingPsbt,
                    inputs: decodeBitcoinPsbt(publicFundingPsbt).inputs,
                    owner: SpendOwner(protocol: 'ark', session: 'board'),
                  ),
                  context: 'context',
                ),
              );
              final tx = decodeBitcoinPsbt(publicFundingPsbt);
              final revision = WalletRevision(
                key: fundingKey,
                generation: 1,
                revision: 2,
              );
              sourceOk(
                await funding.observe(
                  fundingKey,
                  WalletTransactions.ready(
                    ChainTransactionList([
                      BitcoinTransaction(
                        txid: tx.txid,
                        feeSat: 200,
                        vsize: tx.vsize,
                        confirmationTime: 1700000000,
                        inputs: [],
                        outputs: [],
                        sentSat: 100200,
                        receivedSat: 0,
                        isExplicitlyRbf: false,
                      ),
                    ]),
                    revision,
                  ),
                  admittedRevision: revision,
                ),
              );
            }
            final custody = await funding.getCustodyFingerprints();
            expect(custody, isA<Ok>());
            expect((custody as Ok).value, isEmpty);
          } finally {
            funding.close();
          }
          if (scenario == 'unreadable registry') {
            File('${directory.path}/ark/accounts.sqlite')
                .writeAsStringSync('unreadable');
          }
          if (scenario == 'unreadable funding') {
            File(path).writeAsStringSync('unreadable');
          }
          await compose();
          final storage = _SecureStorage(parent)..install();
          final secrets = Secrets(scratchDirectory: () async => directory.path);
          final result = await locator<SeedReferences>().deleteUnreferenced(
            secrets,
            parent,
          );
          expect(result, isA<Err<void, ParentCustodyFailure>>());
          expect(
            (result as Err<void, ParentCustodyFailure>).failure,
            scenario.startsWith('unreadable')
                ? isA<ParentCustodyInventoryFailure>()
                : isA<ParentCustodyReferencedFailure>(),
          );
          expect(
            storage.parentDeletes,
            0,
            reason: 'Secrets.trash must never delete the parent',
          );
          expect(locator.isRegistered<ArkForegroundHost>(), isFalse);
        },
      );
    }
    test(
      'never-provisioned ordinary regtest signing remains available',
      () async {
        await compose();
        expect(
          await locator<ArkFundingSigningGuard>().admit(
            key: fundingKey,
            unsignedPsbt: publicFundingPsbt,
          ),
          isA<Ok>(),
        );
        expect(Directory('${directory.path}/ark').existsSync(), isFalse);
        expect(
          File('${directory.path}/ark-funding.sqlite').existsSync(),
          isFalse,
        );
      },
    );
  });

  test(
    'fresh app composes wallet dependencies before starting SP watchers',
    () async {
      final directory = await Directory.systemTemp.createTemp('app_locator_');
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FakeSecureStoragePlatform().install();
      SharedPreferences.setMockInitialValues({});
      final database = SqliteDatabase(NativeDatabase.memory());
      final locator = GetIt.asNewInstance();
      final nativeTor = _NativeTor();
      locator.registerSingleton<TorNativeInitializer>(nativeTor);
      var composed = false;
      addTearDown(() async {
        if (composed) {
          await locator<SpTipWatcher>().dispose();
          await locator<SpElectrumReconnectWatcher>().dispose();
          locator<SyncCoordinator>().dispose();
        }
        await locator.reset();
        await database.close();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });

      final result = await AppLocator.setup(
        locator,
        database,
        payjoinDatabasePath: '${directory.path}/payjoin.sqlite',
        startPayjoinRecovery: false,
        startOrderSwapWatcher: false,
        startAutoswapWatcher: false,
      );
      expect(result, isA<Ok>());
      composed = true;
      expect(nativeTor.calls, 1);
      expect(locator<WalletRepository>(), isA<WalletRepository>());
    },
  );
  test('regtest provisioning failure returns a typed Err before wallet runtime registration', () async {
    final directory = await Directory.systemTemp.createTemp(
      'app_locator_failure_',
    );
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    FakeSecureStoragePlatform().install();
    SharedPreferences.setMockInitialValues({});
    final database = SqliteDatabase(NativeDatabase.memory());
    final locator = GetIt.asNewInstance();
    locator.registerSingleton<TorNativeInitializer>(_NativeTor());
    addTearDown(() async {
      await locator.reset();
      await database.close();
      PathProviderPlatform.instance = previousPaths;
      await directory.delete(recursive: true);
    });
    await database.select(database.settings).get();
    await database
        .update(database.settings)
        .write(
          const SettingsCompanion(
            environment: Value('regtest'),
            isSuperuser: Value(true),
            isDevModeEnabled: Value(true),
          ),
        );
    await database.delete(database.electrumSettings).go();
    await database.delete(database.electrumServers).go();
    await database.customStatement(
      "CREATE TRIGGER fail_boot_regtest BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' BEGIN SELECT RAISE(ABORT, 'fixture provisioning failure'); END",
    );
    final result = await AppLocator.setup(
      locator,
      database,
      payjoinDatabasePath: '${directory.path}/payjoin.sqlite',
      startPayjoinRecovery: false,
      startOrderSwapWatcher: false,
      startAutoswapWatcher: false,
      regtestProfile: RegtestElectrumProfile(host: '127.0.0.1'),
    );
    expect(result, isA<Err<void, ElectrumFailure>>());
    expect(
      (result as Err<void, ElectrumFailure>).failure,
      isA<ElectrumSaveFailure>(),
    );
    expect(locator.isRegistered<WalletRepository>(), isFalse);
    expect(locator.isRegistered<SyncCoordinator>(), isFalse);
    expect(locator.isRegistered<SpTipWatcher>(), isFalse);
    expect(await database.select(database.electrumServers).get(), isEmpty);
    expect(await database.select(database.electrumSettings).get(), isEmpty);
  });
}
