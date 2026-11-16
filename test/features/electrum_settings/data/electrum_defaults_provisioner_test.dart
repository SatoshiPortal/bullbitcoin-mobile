import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart'
    show ElectrumSettingsFacade, RegtestElectrumProfile;

import 'dart:io';

import 'package:bb_mobile/core/electrum/adapters/drift_electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/electrum_settings/data/drift_electrum_server_repository.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_defaults_provisioner.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_servers_adapter.dart';
import 'package:bb_mobile/features/electrum_settings/data/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_environment.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _AppSettings extends Mock implements SettingsRepository {}

class _Environment extends Mock implements EnvironmentPort {}

class _Status extends Mock implements ServerStatusPort {}

class _Tor extends Mock implements ElectrumTorSessionPort {}

void main() {
  late SqliteDatabase database;
  late ElectrumDefaultsProvisioner provisioner;
  late DriftElectrumServerRepository servers;
  late DriftElectrumSettingsRepository settings;
  late _AppSettings app;
  late _Environment environment;
  late _Status status;
  late _Tor tor;

  setUpAll(() {
    registerFallbackValue(ElectrumServerNetwork.liquidRegtest);
  });

  setUp(() async {
    database = SqliteDatabase(NativeDatabase.memory());
    // Model an interrupted or older unreleased foreground provisioning.
    await database.select(database.electrumSettings).get();
    await database.delete(database.electrumSettings).go();
    await database.delete(database.electrumServers).go();
    provisioner = ElectrumDefaultsProvisioner(database);
    servers = DriftElectrumServerRepository(
      electrumServerStorageDatasource: ElectrumServerStorageDatasource(
        sqlite: database,
      ),
    );
    settings = DriftElectrumSettingsRepository(
      electrumSettingsStorageDatasource: ElectrumSettingsStorageDatasource(
        sqlite: database,
      ),
    );
    app = _AppSettings();
    when(() => app.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.regtest,
        isSuperuser: true,
        isDevModeEnabled: true,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    environment = _Environment();
    when(() => environment.getEnvironment())
        .thenAnswer((_) async => ElectrumEnvironment.regtest);
    status = _Status();
    when(
      () => status.checkElectrum(
        url: any(named: 'url'),
        network: any(named: 'network'),
        validateDomain: any(named: 'validateDomain'),
        timeout: any(named: 'timeout'),
        retry: any(named: 'retry'),
        proxyEndpoint: any(named: 'proxyEndpoint'),
      ),
    ).thenAnswer((_) async => ElectrumServerStatus.online);
    tor = _Tor();
    when(
      () => tor.open(
        network: any(named: 'network'),
        serverUrl: any(named: 'serverUrl'),
        isCustom: any(named: 'isCustom'),
        externalProxyEnabled: any(named: 'externalProxyEnabled'),
        externalProxyPort: any(named: 'externalProxyPort'),
      ),
    ).thenAnswer((_) async => null);
  });
  tearDown(() => database.close());

  ElectrumServersAdapter adapter(ElectrumDefaultsProvisioner readiness) =>
      ElectrumServersAdapter(
        storageReadiness: readiness,
        serverRepository: servers,
        settingsRepository: settings,
        appSettingsRepository: app,
        torSessionPort: tor,
      );
  LoadElectrumServerDataUsecase loader() => LoadElectrumServerDataUsecase(
    storageReadiness: provisioner,
    electrumServerRepository: servers,
    electrumSettingsRepository: settings,
    environmentPort: environment,
    serverStatusPort: status,
    torSessionPort: tor,
    settingsRepository: app,
  );

  test(
    'both first parallel readers wait for the same foreground transaction',
    () async {
      final preparation = provisioner.prepareForegroundStorage(
        NetworkEnv.regtest,
      );
      final (connection, response, prepared) = await (
        adapter(provisioner).runWithFallback(
          network: ElectrumServerNetwork.liquidRegtest,
          operation: (connection) async => connection,
        ),
        loader().execute(LoadElectrumServerDataRequest(isLiquid: true)),
        preparation,
      ).wait;
      expect(prepared, isA<Ok>());
      expect(connection.url, 'tcp://127.0.0.1:50001');
      expect(connection.validateDomain, isTrue);
      response.fold((value) {
        expect(
          value.servers.single.network,
          ElectrumServerNetwork.liquidRegtest,
        );
        expect(value.settings.network, ElectrumServerNetwork.liquidRegtest);
      }, (failure) => fail('Unexpected ${failure.runtimeType}'));
    },
  );

  test('unprepared readers fail closed without writes or probes', () async {
    expect(
      await loader().execute(LoadElectrumServerDataRequest(isLiquid: true)),
      isA<Err>(),
    );
    await expectLater(
      adapter(provisioner).runWithFallback(
        network: ElectrumServerNetwork.liquidRegtest,
        operation: (_) async => fail('Unexpected transport'),
      ),
      throwsA(isA<ElectrumStorageNotReadyException>()),
    );
    expect(await database.select(database.electrumSettings).get(), isEmpty);
    expect(await database.select(database.electrumServers).get(), isEmpty);
    verifyZeroInteractions(status);
    verifyZeroInteractions(tor);
  });

  test('repeat/concurrent preparation preserves custom endpoints, priorities and options', () async {
    const network = ElectrumServerNetwork.liquidRegtest;
    await database
        .into(database.electrumSettings)
        .insert(
          const ElectrumSettingsRow(
            network: network,
            validateDomain: false,
            stopGap: 111,
            timeout: 42,
            retry: 7,
            socks5: '127.0.0.1:19050',
          ),
        );
    // A user may have chosen even the canonical endpoint as a custom server.
    await database
        .into(database.electrumServers)
        .insert(
          const ElectrumServerRow(
            url: 'tcp://127.0.0.1:50001',
            network: 'liquidRegtest',
            priority: 12,
            isCustom: true,
          ),
        );
    await database
        .into(database.electrumServers)
        .insert(
          const ElectrumServerRow(
            url: 'ssl://custom.example:50002',
            network: 'liquidRegtest',
            priority: 4,
            isCustom: true,
          ),
        );
    await Future.wait(
      List.generate(
        4,
        (_) => provisioner.prepareForegroundStorage(NetworkEnv.regtest),
      ),
    );
    await provisioner.prepareForegroundStorage(NetworkEnv.regtest);
    final row = await database.managers.electrumSettings
        .filter((f) => f.network(network))
        .getSingle();
    expect(
      (row.validateDomain, row.stopGap, row.timeout, row.retry, row.socks5),
      (false, 111, 42, 7, '127.0.0.1:19050'),
    );
    final result = await servers.fetchActiveServers(network: network);
    result.fold((values) {
      expect(values.map((value) => value.priority), [4, 12]);
      expect(values.every((value) => value.isCustom), isTrue);
    }, (failure) => fail('Unexpected ${failure.runtimeType}'));
  });

  test('read-only background never repairs missing rows', () async {
    final readonly = ElectrumDefaultsProvisioner(database, readOnly: true);
    expect(
      await readonly.requireReady(ElectrumServerNetwork.liquidRegtest),
      isA<Err>(),
    );
    expect(
      await readonly.prepareForegroundStorage(NetworkEnv.regtest),
      isA<Err>(),
    );
    expect(await database.select(database.electrumSettings).get(), isEmpty);
    expect(await database.select(database.electrumServers).get(), isEmpty);
    await provisioner.prepareForegroundStorage(NetworkEnv.regtest);
    expect(
      await readonly.requireReady(ElectrumServerNetwork.liquidRegtest),
      isA<Ok>(),
    );
    await database.delete(database.electrumServers).go();
    expect(
      await readonly.requireReady(ElectrumServerNetwork.bitcoinRegtest),
      isA<Err>(),
    );
    expect(await database.select(database.electrumServers).get(), isEmpty);
  });

  test(
    'an interrupted server insert rolls back settings and can be retried',
    () async {
      await database.customStatement(
        "CREATE TRIGGER interrupt_liquid BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' BEGIN SELECT RAISE(ABORT, 'simulated interruption'); END",
      );
      expect(
        await provisioner.prepareForegroundStorage(NetworkEnv.regtest),
        isA<Err>(),
      );
      expect(await database.select(database.electrumSettings).get(), isEmpty);
      expect(await database.select(database.electrumServers).get(), isEmpty);
      expect(
        await provisioner.requireReady(ElectrumServerNetwork.liquidRegtest),
        isA<Err>(),
      );
      await database.customStatement('DROP TRIGGER interrupt_liquid');
      expect(
        await provisioner.prepareForegroundStorage(NetworkEnv.regtest),
        isA<Ok>(),
      );
      expect(
        await provisioner.requireReady(ElectrumServerNetwork.liquidRegtest),
        isA<Ok>(),
      );
    },
  );

  test('two foreground connections preserve one canonical set', () async {
    final directory = Directory.systemTemp.createTempSync(
      'electrum-provision-',
    );
    final file = File('${directory.path}/test.sqlite');
    final first = SqliteDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (db) => db.execute('PRAGMA busy_timeout = 2000'),
      ),
    );
    SqliteDatabase? second;
    try {
      await first.select(first.electrumSettings).get();
      await first.delete(first.electrumSettings).go();
      await first.delete(first.electrumServers).go();
      final other = second = SqliteDatabase(
        NativeDatabase.createInBackground(
          file,
          setup: (db) => db.execute('PRAGMA busy_timeout = 2000'),
        ),
      );
      final results = await Future.wait([
        ElectrumDefaultsProvisioner(first)
            .prepareForegroundStorage(NetworkEnv.regtest),
        ElectrumDefaultsProvisioner(other)
            .prepareForegroundStorage(NetworkEnv.regtest),
      ]);
      expect(results, everyElement(isA<Ok>()));
      expect(await first.select(first.electrumSettings).get(), hasLength(2));
      expect(await other.select(other.electrumServers).get(), hasLength(2));
    } finally {
      await second?.close();
      await first.close();
      directory.deleteSync(recursive: true);
    }
  });

  test('configured host replaces only managed defaults, preserving priority and custom URLs', () async {
    await provisioner.prepareForegroundStorage(NetworkEnv.regtest);
    await database.customStatement(
      "UPDATE electrum_servers SET priority = 9 WHERE is_custom = 0",
    );
    await database
        .into(database.electrumServers)
        .insert(
          const ElectrumServerRow(
            url: 'tcp://custom.example:60001',
            network: 'liquidRegtest',
            priority: 3,
            isCustom: true,
          ),
        );
    final facade = ElectrumSettingsFacade(
      prepareForegroundStorage: provisioner.prepareForegroundStorage,
    );
    expect(
      await facade.prepareForegroundStorage(
        NetworkEnv.regtest,
        regtestProfile: RegtestElectrumProfile(host: 'stack.example'),
      ),
      isA<Ok>(),
    );
    final defaults = await database.managers.electrumServers
        .filter((f) => f.isCustom(false))
        .get();
    expect(
      defaults.map((row) => row.url),
      unorderedEquals([
        'tcp://stack.example:50000',
        'tcp://stack.example:50001',
      ]),
    );
    expect(defaults.every((row) => row.priority == 9), isTrue);
    final active = await servers.fetchActiveServers(
      network: ElectrumServerNetwork.liquidRegtest,
    );
    active.fold(
      (values) => expect(values.single.url, 'tcp://custom.example:60001'),
      (failure) => fail('Unexpected ${failure.runtimeType}'),
    );
    expect(
      await provisioner.requireReady(ElectrumServerNetwork.liquidRegtest),
      isA<Ok>(),
    );
    // A headless process with the default build host cannot reuse stale defaults.
    expect(
      await ElectrumDefaultsProvisioner(
        database,
        readOnly: true,
      ).requireReady(ElectrumServerNetwork.liquidRegtest),
      isA<Err>(),
    );
  });

  for (final production in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    test('$production preparation does not create fixture data', () async {
      expect(await provisioner.prepareForegroundStorage(production), isA<Ok>());
      expect(await database.select(database.electrumSettings).get(), isEmpty);
      expect(await database.select(database.electrumServers).get(), isEmpty);
    });
  }
}
