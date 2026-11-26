import 'package:preferences/migration.dart';
import 'package:preferences/testing.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:mocktail/mocktail.dart';

import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/app_database_testing.dart';
import 'package:bull_ark/ark_background_setup.dart';
import 'package:bull_ark/ark_setup.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show recoverBullDefaultServerUrl;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:primitives/primitives.dart';

class _Client extends Mock implements ArkClient {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Directory locks;
  late PathProviderPlatform previousPaths;
  late BackgroundTaskResources resources;
  late DatabaseKeys keys;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ark-background-host-');
    locks = await Directory.systemTemp.createTemp('ark-background-lock-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(directory.path);
    FakeSecureStoragePlatform().install();
    keys = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    ).databaseKeys(module: 'preferences');
    resources = BackgroundTaskResources(
      admission: await NativeFileGate(
        File('${locks.path}/lifecycle.lock'),
      ).acquire(exclusive: false, timeout: Duration.zero) as RuntimeAdmission,
    );
  });
  tearDown(() async {
    await resources.close();
    await locks.delete(recursive: true);
    PathProviderPlatform.instance = previousPaths;
    await directory.delete(recursive: true);
  });

  Future<void> root(String environment) async {
    final db = SqliteDatabase(
      NativeDatabase(File('${directory.path}/${SqliteDatabase.name}.sqlite')),
    );
    try {
      await db.select(db.settings).get();
      await db
          .update(db.settings)
          .write(
            SettingsCompanion(
              environment: Value(environment),
              isSuperuser: const Value(true),
              isDevModeEnabled: const Value(true),
            ),
          );
    } finally {
      await db.close();
    }
    expect(await SqliteDatabase.isAtCurrentSchema(), isTrue);
    await resources.close();
    final gate = NativeFileGate(File('${locks.path}/lifecycle.lock'));
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    final prepared = await PreferencesImport(
      file: File('${directory.path}/preferences.sqlite'),
      defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
      testingKeys: keys,
    ).prepare(exclusive, OwnerOrigin.legacy);
    final owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
    expect(
      await owner.importLegacy(
        LegacySource(
          File('${directory.path}/${SqliteDatabase.name}.sqlite'),
          16,
        ),
      ),
      isA<Ok>(),
    );
    await exclusive.close();
    resources = BackgroundTaskResources(
      admission: await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission,
    );
  }

  for (final environment in ['mainnet', 'testnet']) {
    test(
      '$environment selection still inspects the existing protected inventory',
      () async {
        await root(environment);
        final ark = Directory('${directory.path}/ark')..createSync();
        final registry = SqliteArkAccountRegistry.open(
          '${ark.path}/accounts.sqlite',
          foreground: true,
          initializeNew: true,
        );
        expect(registry, isA<Ok>());
        (registry as Ok<SqliteArkAccountRegistry, ArkFailure>).value.close();
        File('${ark.path}/accounts.sqlite').writeAsStringSync('unreadable');
        await expectLater(
          setupArkBackgroundTask(
            resources,
            directory,
            preferencesFile: File('${directory.path}/preferences.sqlite'),
            openPreferences: (file, admission) => PreferencesTesting.open(
              file: file,
              admission: admission,
              keys: keys,
            ),
          ),
          throwsStateError,
        );
      },
    );
  }
  for (final environment in ['mainnet', 'testnet']) {
    test(
      '$environment retains saved delivery then renewal for the captured regtest account',
      () async {
        await root(environment);
        final ark = Directory('${directory.path}/ark')..createSync();
        final registry = (SqliteArkAccountRegistry.open(
          '${ark.path}/accounts.sqlite',
          foreground: true,
          initializeNew: true,
        ) as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
        final account = ArkAccountId(
          parent: Fingerprint('00112233'),
          network: BitcoinNetwork.regtest,
          serverIdentity: 'http://captured.regtest',
        );
        final config = ArkAccountConfig(
          id: account,
          arkUrl: Uri.parse('http://captured.regtest'),
          primaryEsploraUrl: Uri.parse('http://chain.regtest'),
        );
        expect(await registry.publish(config), isA<Ok>());
        registry.close();
        final client = _Client();
        final txid = List.filled(32, '42').join();
        final operation = ArkOperation(
          id: 'saved-claim',
          kind: ArkOperationKind.claim,
          status: ArkOperationStatus.outcomeUnknown,
          chainSource: config.primaryEsploraUrl,
          configGeneration: 1,
          actualIds: ['actual'],
          skippedIds: [],
          claimRecovery: ArkClaimRecovery(
            txid: txid,
            destination: 'saved-public-destination',
            net: Sats.fromInt(900),
            fee: Sats.fromInt(100),
          ),
        );
        final snapshot = ArkSnapshot(
          account: account,
          revision: 9,
          observedAt: DateTime.utc(2026),
          stale: true,
          recovery: ArkRecoveryStatus.unknown,
          operations: [operation],
        );
        final submission = ArkSubmission.rebroadcastClaim(
          operationId: operation.id,
          expectedTxid: txid,
        );
        when(() => client.read(account)).thenAnswer((_) async => Ok(snapshot));
        registerFallbackValue(submission);
        when(() => client.submit(account, any()))
            .thenAnswer((_) async => Ok(operation));
        when(() => client.synchronize(account, renew: true)).thenAnswer(
          (_) async => Ok(
            ArkPassOutcome(
              snapshot: snapshot,
              completedStages: {ArkStage.vtxos},
            ),
          ),
        );
        when(client.close).thenAnswer((_) async {});
        final handler = await setupArkBackgroundTask(
          resources,
          directory,
          preferencesFile: File('${directory.path}/preferences.sqlite'),
          openPreferences: (file, admission) => PreferencesTesting.open(
            file: file,
            admission: admission,
            keys: keys,
          ),
          existingClient: (policy, budget) {
            expect(
              policy.mayRun(
                account,
                native.ArkExecutionMode.backgroundExisting,
              ),
              isTrue,
            );
            expect(
              policy.mayRun(account, native.ArkExecutionMode.foreground),
              isFalse,
            );
            expect(budget.mayAdmitNextStage, isTrue);
            return client;
          },
        );
        // Linux has no platform reminders: retry does not skip either native lane.
        expect((await handler()).shouldRetry, isTrue);
        verifyInOrder([
          () => client.read(account),
          () => client.submit(
            account,
            any(
              that: isA<ArkRebroadcastClaim>()
                  .having((s) => s.operationId, 'operation', operation.id)
                  .having((s) => s.expectedTxid, 'txid', txid),
            ),
          ),
          () => client.synchronize(account, renew: true),
        ]);
        verifyNoMoreInteractions(client);
        expect(
          File('${directory.path}/ark-funding.sqlite').existsSync(),
          isFalse,
        );
        expect(Directory('${ark.path}/native').existsSync(), isFalse);
        await resources.close();
        verify(client.close).called(1);
      },
    );
  }

  test('existing-only host filters unsupported persisted networks before either lane', () async {
    await root('mainnet');
    final ark = Directory('${directory.path}/ark')..createSync();
    final registry = (SqliteArkAccountRegistry.open(
      '${ark.path}/accounts.sqlite',
      foreground: true,
      initializeNew: true,
    ) as Ok<SqliteArkAccountRegistry, ArkFailure>).value;
    final client = _Client();
    when(client.close).thenAnswer((_) async {});
    for (final network in [
      BitcoinNetwork.mainnet,
      BitcoinNetwork.testnet,
      BitcoinNetwork.signet,
    ]) {
      final config = ArkAccountConfig(
        id: ArkAccountId(
          parent: Fingerprint('00112233'),
          network: network,
          serverIdentity: 'https://unsupported',
        ),
        arkUrl: Uri.parse('https://unsupported'),
        primaryEsploraUrl: Uri.parse('https://unsupported-chain'),
      );
      expect(await registry.publish(config), isA<Ok>());
    }
    registry.close();
    final handler = await setupArkBackgroundTask(
      resources,
      directory,
      preferencesFile: File('${directory.path}/preferences.sqlite'),
      openPreferences: (file, admission) =>
          PreferencesTesting.open(file: file, admission: admission, keys: keys),
      existingClient: (policy, budget) => client,
    );
    await handler();
    verifyNoMoreInteractions(client);
  });

  test('missing root schema does not open Ark or construct a client', () async {
    var clients = 0;
    final handler = await setupArkBackgroundTask(
      resources,
      directory,
      preferencesFile: File('${directory.path}/preferences.sqlite'),
      openPreferences: (file, admission) =>
          PreferencesTesting.open(file: file, admission: admission, keys: keys),
      existingClient: (_, _) {
        clients++;
        return _Client();
      },
    );
    expect((await handler()).shouldRetry, isTrue);
    expect(clients, 0);
    expect(directory.listSync(), isEmpty);
  });

  test('missing account store is refused without creating authority', () async {
    await root('mainnet');
    var clients = 0;
    await expectLater(
      setupArkBackgroundTask(
        resources,
        directory,
        preferencesFile: File('${directory.path}/preferences.sqlite'),
        openPreferences: (file, admission) => PreferencesTesting.open(
          file: file,
          admission: admission,
          keys: keys,
        ),
        existingClient: (_, _) {
          clients++;
          return _Client();
        },
      ),
      throwsStateError,
    );
    expect(clients, 0);
    expect(Directory('${directory.path}/ark').existsSync(), isFalse);
    expect(File('${directory.path}/ark-funding.sqlite').existsSync(), isFalse);
  });

  test('headless Ark defers without a ready Preferences owner', () async {
    await root('mainnet');
    final missing = File('${directory.path}/missing-preferences.sqlite');
    final handler = await setupArkBackgroundTask(
      resources,
      directory,
      preferencesFile: missing,
      openPreferences: (file, admission) =>
          PreferencesTesting.open(file: file, admission: admission, keys: keys),
      existingClient: (_, _) => fail('Ark must not open without Preferences'),
    );
    expect((await handler()).shouldRetry, isTrue);
    expect(missing.existsSync(), isFalse);
    expect(Directory('${directory.path}/ark').existsSync(), isFalse);
  });
}
