import 'package:bb_mobile/core/storage/database_seeds.dart';
import 'package:bb_mobile/features/settings/domain/usecases/set_active_network_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_failure.dart';
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
import 'package:bb_mobile/core/storage/tables/electrum_servers_table.drift.dart';
import 'package:bb_mobile/core/storage/tables/electrum_settings_table.drift.dart';
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

final _fixtureProfile = RegtestElectrumProfile(host: '127.0.0.1');

Future<Result<void, ElectrumFailure>> _prepare(
  ElectrumDefaultsProvisioner provisioner,
  NetworkEnv environment, {
  RegtestElectrumProfile? regtestProfile,
}) => provisioner.prepareForegroundStorage(
  environment,
  regtestProfile: regtestProfile ?? _fixtureProfile,
);

/// These database tests explicitly select their local fixture, independently
/// of whether the application build offers a regtest runtime.
class _FixtureElectrumFacade extends ElectrumSettingsFacade {
  _FixtureElectrumFacade(super.provisioner);

  @override
  Future<Result<void, ElectrumFailure>> prepareForegroundStorage(
    NetworkEnv environment, {
    RegtestElectrumProfile? regtestProfile,
  }) => super.prepareForegroundStorage(
    environment,
    regtestProfile: regtestProfile ?? _fixtureProfile,
  );
}

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
    registerFallbackValue(Environment.mainnet);
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
        regtestProfile: _fixtureProfile,
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

  ElectrumServersAdapter adapter() => ElectrumServersAdapter(
    serverRepository: servers,
    settingsRepository: settings,
    appSettingsRepository: app,
    torSessionPort: tor,
  );
  LoadElectrumServerDataUsecase loader() => LoadElectrumServerDataUsecase(
    electrumServerRepository: servers,
    electrumSettingsRepository: settings,
    environmentPort: environment,
    serverStatusPort: status,
    torSessionPort: tor,
    settingsRepository: app,
  );

  Future<Result<LoadElectrumServerDataResponse, ElectrumFailure>> loadNetwork(
    ElectrumServerNetwork network,
  ) {
    when(() => environment.getEnvironment())
        .thenAnswer((_) async => network.environment);
    return loader().execute(
      LoadElectrumServerDataRequest(isLiquid: network.isLiquid),
    );
  }

  SetActiveNetworkUsecase selector() => SetActiveNetworkUsecase(
    settingsRepository: app,
    electrumSettings: _FixtureElectrumFacade(provisioner),
  );

  Future<void> seedProductionCatalogs() async {
    await DatabaseSeeds.seedDefaultElectrumServers(database);
    await DatabaseSeeds.seedDefaultElectrumSettings(database);
    for (final network in [
      ElectrumServerNetwork.bitcoinRegtest,
      ElectrumServerNetwork.liquidRegtest,
    ]) {
      await database.managers.electrumSettings
          .filter((f) => f.network(network))
          .delete();
      await database.managers.electrumServers
          .filter((f) => f.network.equals(network.storageName))
          .delete();
    }
  }

  test(
    'foreground provisioning completes before the first parallel readers',
    () async {
      final prepared = await _prepare(provisioner, NetworkEnv.regtest);
      final (connection, response) = await (
        adapter().runWithFallback(
          network: ElectrumServerNetwork.liquidRegtest,
          operation: (connection) async => connection,
        ),
        loader().execute(LoadElectrumServerDataRequest(isLiquid: true)),
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
      adapter().runWithFallback(
        network: ElectrumServerNetwork.liquidRegtest,
        operation: (_) async => fail('Unexpected transport'),
      ),
      throwsException,
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
      List.generate(4, (_) => _prepare(provisioner, NetworkEnv.regtest)),
    );
    await _prepare(provisioner, NetworkEnv.regtest);
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
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Err>());
    expect(await _prepare(readonly, NetworkEnv.regtest), isA<Err>());
    expect(await database.select(database.electrumSettings).get(), isEmpty);
    expect(await database.select(database.electrumServers).get(), isEmpty);
    await _prepare(provisioner, NetworkEnv.regtest);
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
    await database.delete(database.electrumServers).go();
    expect(await loadNetwork(ElectrumServerNetwork.bitcoinRegtest), isA<Err>());
    expect(await database.select(database.electrumServers).get(), isEmpty);
  });

  test(
    'an interrupted server insert rolls back settings and can be retried',
    () async {
      await database.customStatement(
        "CREATE TRIGGER interrupt_liquid BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' BEGIN SELECT RAISE(ABORT, 'simulated interruption'); END",
      );
      expect(await _prepare(provisioner, NetworkEnv.regtest), isA<Err>());
      expect(await database.select(database.electrumSettings).get(), isEmpty);
      expect(await database.select(database.electrumServers).get(), isEmpty);
      expect(
        await loadNetwork(ElectrumServerNetwork.liquidRegtest),
        isA<Err>(),
      );
      await database.customStatement('DROP TRIGGER interrupt_liquid');
      expect(await _prepare(provisioner, NetworkEnv.regtest), isA<Ok>());
      expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
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
        _prepare(ElectrumDefaultsProvisioner(first), NetworkEnv.regtest),
        _prepare(ElectrumDefaultsProvisioner(other), NetworkEnv.regtest),
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
    await _prepare(provisioner, NetworkEnv.regtest);
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
    final facade = _FixtureElectrumFacade(provisioner);
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
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
    // A fresh read-only reader uses persisted endpoints without a process-local gate.
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
  });

  for (final boot in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    test(
      '$boot preparation preserves both production networks for hot switching',
      () async {
        const productionNetworks = [
          ElectrumServerNetwork.bitcoinMainnet,
          ElectrumServerNetwork.liquidMainnet,
          ElectrumServerNetwork.bitcoinTestnet,
          ElectrumServerNetwork.liquidTestnet,
        ];
        for (final network in productionNetworks) {
          await database
              .into(database.electrumSettings)
              .insert(
                ElectrumSettingsRow(
                  network: network,
                  validateDomain: true,
                  stopGap: 20,
                  timeout: 5,
                  retry: 5,
                ),
              );
          await database
              .into(database.electrumServers)
              .insert(
                ElectrumServerRow(
                  url: 'ssl://${network.storageName}.example:50002',
                  network: network.storageName,
                  priority: 0,
                  isCustom: false,
                ),
              );
        }
        expect(await _prepare(provisioner, boot), isA<Ok>());
        for (final network in productionNetworks) {
          expect(await loadNetwork(network), isA<Ok>());
        }
        expect(
          await database.select(database.electrumSettings).get(),
          hasLength(4),
        );
        expect(
          await database.select(database.electrumServers).get(),
          hasLength(4),
        );
      },
    );
  }

  for (final production in [NetworkEnv.mainnet, NetworkEnv.testnet]) {
    test('$production preparation does not create fixture data', () async {
      expect(await _prepare(provisioner, production), isA<Ok>());
      expect(await database.select(database.electrumSettings).get(), isEmpty);
      expect(await database.select(database.electrumServers).get(), isEmpty);
    });
  }
  test(
    'hot selector production boot to regtest provisions before activation',
    () async {
      await seedProductionCatalogs();
      expect(await _prepare(provisioner, NetworkEnv.mainnet), isA<Ok>());
      var selected = Environment.mainnet;
      var callbacks = 0;
      var catalogPresentAtActivation = false;
      when(() => app.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: selected,
          isSuperuser: true,
          isDevModeEnabled: true,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(() => app.setEnvironment(any())).thenAnswer((invocation) async {
        callbacks++;
        final rows = await servers.fetchAll(
          network: ElectrumServerNetwork.liquidRegtest,
        );
        catalogPresentAtActivation = rows.fold(
          (value) => value.isNotEmpty,
          (_) => false,
        );
        selected = invocation.positionalArguments.single as Environment;
        return const Ok(null);
      });
      expect(await selector().execute(NetworkEnv.regtest), isA<Ok>());
      expect(catalogPresentAtActivation, isTrue);
      expect(selected, Environment.regtest);
      expect(callbacks, 1);
      expect(
        await loadNetwork(ElectrumServerNetwork.bitcoinRegtest),
        isA<Ok>(),
      );
      expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
    },
  );

  for (final target in [Environment.mainnet, Environment.testnet]) {
    test(
      'hot selector regtest boot to $target leaves production readers usable',
      () async {
        await seedProductionCatalogs();
        expect(await _prepare(provisioner, NetworkEnv.regtest), isA<Ok>());
        var selected = Environment.regtest;
        when(() => app.fetch()).thenAnswer(
          (_) async => SettingsEntity(
            environment: selected,
            isSuperuser: true,
            isDevModeEnabled: true,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        );
        when(() => app.setEnvironment(any())).thenAnswer((invocation) async {
          selected = invocation.positionalArguments.single as Environment;
          return const Ok(null);
        });
        expect(await selector().execute(target.networkEnv), isA<Ok>());
        expect(selected, target);
        for (final liquid in [false, true]) {
          final network = ElectrumServerNetwork.fromNetworkEnv(
            target.networkEnv,
            isLiquid: liquid,
          );
          expect(await loadNetwork(network), isA<Ok>());
          final connection = await adapter().runWithFallback(
            network: network,
            operation: (connection) async => connection,
          );
          expect(connection.url, isNotEmpty);
        }
      },
    );
  }

  test('hot selector provisioning failure rolls back both tables and never activates', () async {
    var selected = Environment.mainnet;
    var callbacks = 0;
    when(() => app.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: selected,
        isSuperuser: true,
        isDevModeEnabled: true,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(() => app.setEnvironment(any())).thenAnswer((invocation) async {
      callbacks++;
      selected = invocation.positionalArguments.single as Environment;
      return const Ok(null);
    });
    await database.customStatement(
      "CREATE TRIGGER fail_select_regtest BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' BEGIN SELECT RAISE(ABORT, 'fixture provisioning failure'); END",
    );
    expect(await selector().execute(NetworkEnv.regtest), isA<Err>());
    expect(selected, Environment.mainnet);
    expect(callbacks, 0);
    expect(await database.select(database.electrumServers).get(), isEmpty);
    expect(await database.select(database.electrumSettings).get(), isEmpty);
  });

  test('colliding custom default survives provisioning then delete restores and reloads it', () async {
    final profile = RegtestElectrumProfile(host: 'stack.example');
    final datasource = ElectrumServerStorageDatasource(
      sqlite: database,
      regtestProfile: profile,
    );
    servers = DriftElectrumServerRepository(
      electrumServerStorageDatasource: datasource,
    );
    expect(
      await _prepare(provisioner, NetworkEnv.regtest, regtestProfile: profile),
      isA<Ok>(),
    );
    final url = profile.endpoint(isLiquid: true);
    await datasource.store(
      ElectrumServerModel(
        url: url,
        network: ElectrumServerNetwork.liquidRegtest,
        priority: 12,
        isCustom: true,
      ),
    );
    await _prepare(provisioner, NetworkEnv.regtest, regtestProfile: profile);
    final preserved = await datasource.fetchByUrl(
      url,
      network: ElectrumServerNetwork.liquidRegtest,
    );
    expect(preserved?.isCustom, isTrue);
    expect(preserved?.priority, 12);
    expect(
      await servers.delete(
        url: url,
        network: ElectrumServerNetwork.liquidRegtest,
      ),
      isA<Ok>(),
    );
    final restored = await datasource.fetchByUrl(
      url,
      network: ElectrumServerNetwork.liquidRegtest,
    );
    expect(restored?.isCustom, isFalse);
    expect(restored?.priority, 0);
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
  });

  test(
    'colliding custom restore failure rolls back the deletion transaction',
    () async {
      await _prepare(provisioner, NetworkEnv.regtest);
      const url = 'tcp://127.0.0.1:50001';
      final datasource = ElectrumServerStorageDatasource(
        sqlite: database,
        regtestProfile: _fixtureProfile,
      );
      await datasource.store(
        ElectrumServerModel(
          url: url,
          network: ElectrumServerNetwork.liquidRegtest,
          priority: 9,
          isCustom: true,
        ),
      );
      await database.customStatement(
        "CREATE TRIGGER fail_default_restore BEFORE INSERT ON electrum_servers WHEN NEW.network = 'liquidRegtest' AND NEW.is_custom = 0 BEGIN SELECT RAISE(ABORT, 'fixture restore failure'); END",
      );
      expect(
        await servers.delete(
          url: url,
          network: ElectrumServerNetwork.liquidRegtest,
        ),
        isA<Err>(),
      );
      final retained = await datasource.fetchByUrl(
        url,
        network: ElectrumServerNetwork.liquidRegtest,
      );
      expect(retained?.isCustom, isTrue);
      expect(retained?.priority, 9);
    },
  );
  test('Liquid readers do not depend on the sibling Bitcoin catalog', () async {
    await _prepare(provisioner, NetworkEnv.regtest);
    await database.managers.electrumSettings
        .filter((f) => f.network(ElectrumServerNetwork.bitcoinRegtest))
        .delete();
    await database.managers.electrumServers
        .filter((f) => f.network.equals('bitcoinRegtest'))
        .delete();
    expect(await loadNetwork(ElectrumServerNetwork.liquidRegtest), isA<Ok>());
    final connection = await adapter().runWithFallback(
      network: ElectrumServerNetwork.liquidRegtest,
      operation: (connection) async => connection,
    );
    expect(connection.url, 'tcp://127.0.0.1:50001');
  });
}
