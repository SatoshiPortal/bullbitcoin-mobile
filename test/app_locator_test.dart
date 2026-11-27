import 'package:go_router/go_router.dart';
import 'package:swap_feature/swap_feature.dart';
import 'package:labels/testing.dart';
import 'package:electrum/testing.dart';
import 'package:preferences/testing.dart';
import 'package:mempool/testing.dart';
import 'package:ark/ark.dart';
import 'package:ark/funding.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:bull_ark/ark_foreground_setup.dart';
import 'package:fees/fees.dart';
import 'package:sync/write.dart'
    show ForegroundWalletSynchronization, WalletNativeRuntime;
import 'package:secrets/custody.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:spend/spend.dart';
import 'package:sync/sync.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';

import 'features/wallet/data/ark_funding_test_fixture.dart';
import 'support/owner_databases.dart';
import 'support/inventory_fixture.dart';

import 'package:primitives/primitives.dart';
import 'package:drift/drift.dart' show Value;
import 'package:electrum/electrum.dart'
    show ElectrumFailure, ElectrumSaveFailure;
import 'package:electrum/setup.dart' show RegtestElectrumProfile;

import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/app_database_testing.dart';
import 'package:overview/setup.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:silent/setup.dart';
import 'package:bb_mobile/locator.dart';
import 'package:startup/startup.dart';
import 'package:drift/native.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:preferences/preferences.dart';
import 'package:secrets/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:settings/setup.dart' show StartupNetwork;
import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinLifecycle;

import 'support/preferences_database.dart';
import '../packages/electrum/test/electrum_test_database.dart';

Future<Result<Preferences, PreferencesFailure>> _openTestPreferences(
  SqliteDatabase legacy,
) async {
  final owner = await createPreferencesDatabase(copySettingsFrom: legacy);
  addTearDown(owner.close);
  return Ok(PreferencesTesting.fromDao(PreferencesDao(owner)));
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

  test(
    'initial network is applied before network services are mounted',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'initial-network-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      FakeSecureStoragePlatform().install();
      SharedPreferences.setMockInitialValues({});
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final database = SqliteDatabase(NativeDatabase.memory());
      final locator = GetIt.asNewInstance();
      registerTestOwnerDatabases(locator);
      final inventory = await InventoryFixture.compose(directory, locator);
      locator.registerSingleton<TorNativeInitializer>(_NativeTor());
      addTearDown(() async {
        await locator.reset();
        await inventory.close();
        await database.close();
        PathProviderPlatform.instance = previousPaths;
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
        await directory.delete(recursive: true);
      });
      var applied = false;
      final result = await AppLocator.setup(
        locator,
        database,
        openLabels: (sync, openWallet) async => Ok(
          createLabelsForTesting(
            database: database,
            sync: sync,
            openWallet: openWallet,
          ),
        ),
        openElectrum: (readPreferences, tor) async => Ok(
          createElectrumForTesting(
            database: database,
            readPreferences: readPreferences,
            tor: tor,
          ),
        ),
        openPreferences: () => _openTestPreferences(database),
        openMempool: (tor, http) async => Ok(
          createMempoolForTesting(database: database, tor: tor, torHttp: http),
        ),
        startPayjoinRecovery: false,
        startOrderSwapWatcher: false,
        startAutoswapWatcher: false,
        prepareInitialNetwork: (preferences, electrum) async {
          expect(locator.isRegistered<PayjoinLifecycle>(), isFalse);
          final secrets = locator<Secrets>();
          final selection = await StartupNetwork.apply(
            preferences: preferences,
            electrum: electrum,
            network: NetworkEnv.testnet,
            superuserUnlocked: true,
            developerConsent: true,
            isProtected: inventory.inventory.isProtected,
            hasWallets: inventory.inventory.hasWallets,
            listSecrets: secrets.list,
          );
          applied = selection is Ok;
          return selection;
        },
      );
      expect(result, isA<Ok>());
      expect(applied, isTrue);
      expect(locator.isRegistered<PayjoinLifecycle>(), isTrue);
      final settings = await locator<Preferences>().fetch();
      expect(
        (settings as Ok<SettingsEntity, PreferencesFailure>).value.environment,
        Environment.testnet,
      );
    },
  );

  group('profile-independent Ark custody at restart', () {
    late Directory directory;
    late GetIt locator;
    late SqliteDatabase database;
    late InventoryFixture inventoryFixture;
    late PathProviderPlatform previousPaths;
    SharedPreferencesAsyncPlatform? previousPreferences;
    final parent = Fingerprint('00112233');
    setUp(() async {
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
      registerTestOwnerDatabases(locator);
      inventoryFixture = await InventoryFixture.compose(directory, locator);
      locator.registerSingleton<TorNativeInitializer>(_NativeTor());
    });
    tearDown(() async {
      await locator.reset();
      await inventoryFixture.close();
      await database.close();
      PathProviderPlatform.instance = previousPaths;
      SharedPreferencesAsyncPlatform.instance = previousPreferences;
      await directory.delete(recursive: true);
    });
    Future<void> compose({
      bool initialize = false,
      bool startWatchers = false,
    }) async {
      expect(
        await AppLocator.setup(
          locator,
          database,
          openLabels: (sync, openWallet) async => Ok(
            createLabelsForTesting(
              database: database,
              sync: sync,
              openWallet: openWallet,
            ),
          ),
          openElectrum: (readPreferences, tor) async => Ok(
            createElectrumForTesting(
              database: database,
              readPreferences: readPreferences,
              tor: tor,
            ),
          ),
          openPreferences: () => _openTestPreferences(database),
          openMempool: (tor, http) async => Ok(
            createMempoolForTesting(
              database: database,
              tor: tor,
              torHttp: http,
            ),
          ),
          arkFundingDatabasePath: '${directory.path}/ark-funding.sqlite',
          initializeArkFunding: initialize,
          startPayjoinRecovery: false,
          startOrderSwapWatcher: startWatchers,
          startAutoswapWatcher: startWatchers,
        ),
        isA<Ok>(),
      );
    }

    Future<void> publishAccount() async {
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
            ),
          ),
          isA<Ok>(),
        );
      } finally {
        registry.close();
      }
    }

    test('PIN protection defers Silent Payments and swap watchers', () async {
      final pin = DateTime.now().microsecondsSinceEpoch.toString();
      expect(await inventoryFixture.inventory.setCredential(pin), isA<Ok>());
      inventoryFixture.inventory.lock();
      await compose(startWatchers: true);
      final swap = locator<SwapFeature>();
      expect(swap.routes.map((route) => route.path), [
        '/swap',
        '/swap-settings',
      ]);
      expect(
        swap.routes.first.routes.cast<GoRoute>().map((route) => route.path),
        ['/swap/confirm'],
      );
      expect(swap.autoswapSettingsRoute.path, 'autoswap-settings');

      expect(locator<SilentFeature>().foregroundWatchersStarted, isFalse);
      expect(locator<SwapFeature>().isWatchingOrders, isFalse);
      expect(locator<SwapFeature>().isWatchingAutoswap, isFalse);

      expect(
        (await inventoryFixture.inventory.unlock(pin))
            .fold((value) => value.accepted, (_) => false),
        isTrue,
      );
      await locator<ForegroundWalletStartup>().start();
      expect(locator<SilentFeature>().foregroundWatchersStarted, isTrue);
      expect(locator<SwapFeature>().isWatchingOrders, isTrue);
      expect(locator<SwapFeature>().isWatchingAutoswap, isTrue);
    });

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
      await ArkForegroundHost.setup(
        locator,
        inventory: locator<SecretsInventory>(),
        boardFunding: () => arkBoardFundingBinding(
          authority: locator<SqliteArkFundingReservations>(),
          runtime: locator<WalletNativeRuntime>(),
          inventory: locator<SecretsInventory>(),
          synchronize: (key) =>
              locator<ForegroundWalletSynchronization>().executeKey(
                key,
                locator<WalletCatalogPort>(),
                reason: SyncReason.manual,
              ),
          secrets: locator<Secrets>(),
          fees: locator<Fees>(),
          custody: locator<ParentCustodyAdmissionPort>(),
        ),
        arkUrl: Uri.parse('http://ark.regtest'),
        primaryEsploraUrl: Uri.parse('http://chain.regtest'),
        initializeNew: true,
        dispatcher: dispatcher,
      );
      expect(locator<ArkForegroundHost>().dispatcher, same(dispatcher));
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
        Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => directory.path,
        ),
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
          final secrets = Secrets(
            authority: unlockedSessionAuthority(),
            scratchDirectory: () async => directory.path,
          );
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
            walletId: fundingKey.id,
            network: fundingKey.network,
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
      final previousPreferences = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final database = SqliteDatabase(NativeDatabase.memory());
      final locator = GetIt.asNewInstance();
      registerTestOwnerDatabases(locator);
      final inventoryFixture = await InventoryFixture.compose(
        directory,
        locator,
      );
      final nativeTor = _NativeTor();
      locator.registerSingleton<TorNativeInitializer>(nativeTor);
      addTearDown(() async {
        await locator.reset();
        await inventoryFixture.close();
        await database.close();
        PathProviderPlatform.instance = previousPaths;
        SharedPreferencesAsyncPlatform.instance = previousPreferences;
        await directory.delete(recursive: true);
      });

      final result = await AppLocator.setup(
        locator,
        database,
        openLabels: (sync, openWallet) async => Ok(
          createLabelsForTesting(
            database: database,
            sync: sync,
            openWallet: openWallet,
          ),
        ),
        openElectrum: (readPreferences, tor) async => Ok(
          createElectrumForTesting(
            database: database,
            readPreferences: readPreferences,
            tor: tor,
          ),
        ),
        openPreferences: () => _openTestPreferences(database),
        openMempool: (tor, http) async => Ok(
          createMempoolForTesting(database: database, tor: tor, torHttp: http),
        ),
        startPayjoinRecovery: false,
        startOrderSwapWatcher: false,
        startAutoswapWatcher: false,
      );
      expect(result, isA<Ok>());
      await locator<ForegroundWalletStartup>().start();
      expect(nativeTor.calls, 1);
      expect(locator<WalletRepository>(), isA<WalletRepository>());
      const id = 'wpkh([01234567/84h/0h/0h])';
      final key = WalletKey(id: id, network: BitcoinNetwork.mainnet);
      final catalog = locator<WalletCatalogPort>();
      final spend = locator<Spend>();
      expect(await catalog.find(key), isA<Err>());
      expect(
        await inventoryFixture.inventory.registerWallet(
          const RegisteredWallet(
            id: id,
            secretFingerprint: null,
            masterFingerprint: '01234567',
            signer: 'none',
            network: 'bitcoinMainnet',
            xpub: 'xpub',
            externalDescriptor: 'wpkh([01234567/84h/0h/0h]xpub/0/*)',
            internalDescriptor: 'wpkh([01234567/84h/0h/0h]xpub/1/*)',
            label: null,
            birthday: null,
            isDefault: false,
          ),
        ),
        isA<Ok>(),
      );
      expect(await catalog.find(key), isA<Ok>());
      expect(await inventoryFixture.inventory.setCredential('1234'), isA<Ok>());
      inventoryFixture.inventory.lock();
      expect(await catalog.list(), isA<Err>());
      expect(
        await spend.validateBitcoinSelection(walletId: id),
        isA<Err<void, SpendFailure>>().having(
          (result) => result.failure,
          'locked inventory failure',
          isA<SpendUnavailableFailure>(),
        ),
      );
      expect(await inventoryFixture.inventory.unlock('1234'), isA<Ok>());
      expect(await catalog.find(key), isA<Ok>());
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
    final electrumDatabase = ElectrumTestDatabase(NativeDatabase.memory());
    final locator = GetIt.asNewInstance();
    registerTestOwnerDatabases(locator);
    final inventoryFixture = await InventoryFixture.compose(directory, locator);
    locator.registerSingleton<TorNativeInitializer>(_NativeTor());
    addTearDown(() async {
      await locator.reset();
      await inventoryFixture.close();
      await electrumDatabase.close();
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
    await electrumDatabase.customStatement(
      "CREATE TRIGGER fail_boot_regtest BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' BEGIN SELECT RAISE(ABORT, 'fixture provisioning failure'); END",
    );
    final result = await AppLocator.setup(
      locator,
      database,
      openLabels: (sync, openWallet) async => Ok(
        createLabelsForTesting(
          database: database,
          sync: sync,
          openWallet: openWallet,
        ),
      ),
      openElectrum: (readPreferences, tor) async => Ok(
        createElectrumForTesting(
          database: electrumDatabase,
          readPreferences: readPreferences,
          tor: tor,
        ),
      ),
      openPreferences: () => _openTestPreferences(database),
      openMempool: (tor, http) async => Ok(
        createMempoolForTesting(database: database, tor: tor, torHttp: http),
      ),
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
    expect(locator.isRegistered<OverviewSynchronization>(), isFalse);
    expect(locator.isRegistered<SilentFeature>(), isFalse);
    expect(
      await electrumDatabase.select(electrumDatabase.electrumServers).get(),
      isEmpty,
    );
    expect(
      await electrumDatabase.select(electrumDatabase.electrumSettings).get(),
      isEmpty,
    );
  });
}

void dispatcher() {}
