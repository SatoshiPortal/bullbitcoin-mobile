import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_server_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_settings_storage_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_settings_model.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_server_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/datasources/mempool_settings_storage_datasource.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_server_model.dart';
import 'package:bb_mobile/core/mempool/frameworks/drift/models/mempool_settings_model.dart';
import 'package:bb_mobile/core/settings/data/settings_datasource.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/swaps/data/auto_swap_settings_repository_impl.dart';
import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late SettingsDatasource settings;
  late SettingsRepository settingsRepository;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    settings = SettingsDatasource(sqlite: database);
    settingsRepository = SettingsRepository(settingsDatasource: settings);
  });

  tearDown(() async {
    await settingsRepository.close();
    await database.close();
  });

  Future<int> revision() async =>
      (await database.select(database.walletBackupStates).getSingleOrNull())
          ?.localRevision ??
      0;

  Future<void> write(String field) => switch (field) {
    'unit' => settings.setBitcoinUnit(BitcoinUnit.btc),
    'currency' => settings.setCurrency('CAD'),
    'language' => settings.setLanguage(Language.franceFrench),
    'theme' => settings.setThemeMode(AppThemeMode.dark),
    'hide amounts' => settings.setHideAmounts(true),
    'environment' => settings.setEnvironment(Environment.testnet),
    'autoswap' => AutoSwapSettingsRepositoryImpl(
      database,
      settingsRepository,
    ).updateAutoSwapParams(const AutoSwap(enabled: false)),
    'electrum settings' =>
      ElectrumSettingsStorageDatasource(sqlite: database).store(
        ElectrumSettingsModel(
          network: ElectrumServerNetwork.bitcoinMainnet,
          validateDomain: false,
          stopGap: 1234,
          timeout: 9,
          retry: 5,
        ),
      ),
    'electrum servers' =>
      ElectrumServerStorageDatasource(sqlite: database).store(
        ElectrumServerModel(
          url: 'ssl://electrum.example.invalid:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
        ),
      ),
    'mempool settings' =>
      MempoolSettingsStorageDatasource(sqlite: database).store(
        MempoolSettingsModel(
          network: 'bitcoinMainnet',
          useForFeeEstimation: false,
        ),
      ),
    'mempool servers' => MempoolServerStorageDatasource(sqlite: database).store(
      MempoolServerModel(
        url: 'mempool.example.invalid',
        isTestnet: false,
        isLiquid: false,
        isCustom: true,
      ),
    ),
    _ => throw ArgumentError.value(field),
  };

  Future<Object> read(String field) => switch (field) {
    'autoswap' => database.select(database.autoSwap).get(),
    'electrum settings' => database.select(database.electrumSettings).get(),
    'electrum servers' => database.select(database.electrumServers).get(),
    'mempool settings' => database.select(database.mempoolSettings).get(),
    'mempool servers' => database.select(database.mempoolServers).get(),
    _ => database.select(database.settings).get(),
  };

  for (final field in [
    'unit',
    'currency',
    'language',
    'theme',
    'hide amounts',
    'environment',
    'autoswap',
    'electrum settings',
    'electrum servers',
    'mempool settings',
    'mempool servers',
  ]) {
    test(
      '$field writes a durable revision and ignores identical values',
      () async {
        final before = await read(field);
        await write(field);
        expect(await read(field), isNot(before));
        expect(await revision(), 1);
        await write(field);
        expect(await revision(), 1);
      },
    );

    test('$field rolls back when the backup revision cannot commit', () async {
      final before = await read(field);
      await database.customStatement('''
        CREATE TRIGGER reject_settings_backup_revision
        BEFORE UPDATE OF local_revision ON wallet_backup_states
        BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
      ''');
      await expectLater(write(field), throwsA(isA<Exception>()));
      expect(await read(field), before);
      expect(await revision(), 0);
    });
  }

  test('device-only app settings do not dirty portable backups', () async {
    await settings.setIsSuperuser(true);
    await settings.setIsDevMode(true);
    await settings.setTorProxy(enabled: true, port: 9051);
    await settings.setErrorReportingEnabled(true);
    await settings.setScreenCaptureProtectionEnabled(false);
    await settings.setExchangeTestnetBasicAuth(
      username: 'fixture',
      password: 'fixture',
    );
    expect(await revision(), 0);
  });

  test(
    'autoswap execution bookkeeping does not dirty portable backups',
    () async {
      final repository = AutoSwapSettingsRepositoryImpl(
        database,
        settingsRepository,
      );
      final previous = await repository.getAutoSwapParams();
      await repository.updateAutoSwapParams(
        previous.copyWith(
          blockTillNextExecution: !previous.blockTillNextExecution,
          showWarning: !previous.showWarning,
        ),
      );
      expect(await revision(), 0);
    },
  );

  test('the local Electrum proxy is not part of the portable backup', () async {
    final repository = ElectrumSettingsStorageDatasource(sqlite: database);
    final previous = await repository.fetchByNetwork(
      ElectrumServerNetwork.bitcoinMainnet,
    );
    await repository.store(
      ElectrumSettingsModel(
        network: previous.network,
        validateDomain: previous.validateDomain,
        stopGap: previous.stopGap,
        timeout: previous.timeout,
        retry: previous.retry,
        socks5: '127.0.0.1:9051',
      ),
    );
    expect(await revision(), 0);
  });

  test(
    'updating built-in Electrum servers does not dirty custom-server backup',
    () async {
      final repository = ElectrumServerStorageDatasource(sqlite: database);
      final previous = (await repository.fetchAllServers(
        isCustom: false,
      )).first;
      await repository.store(
        ElectrumServerModel(
          url: previous.url,
          network: previous.network,
          priority: previous.priority + 1,
        ),
      );
      expect(await revision(), 0);
    },
  );

  for (final field in ['electrum servers', 'mempool servers']) {
    test('$field deletion is atomic and missing deletion is a no-op', () async {
      await write(field);
      final before = await read(field);
      Future<bool> remove() => field == 'electrum servers'
          ? ElectrumServerStorageDatasource(
              sqlite: database,
            ).deleteServer('ssl://electrum.example.invalid:50002')
          : MempoolServerStorageDatasource(
              sqlite: database,
            ).deleteCustomServer(MempoolServerNetwork.bitcoinMainnet);
      await database.customStatement('''
        CREATE TRIGGER reject_settings_backup_revision
        BEFORE UPDATE OF local_revision ON wallet_backup_states
        BEGIN SELECT RAISE(ABORT, 'injected revision failure'); END
      ''');
      expect(await remove(), false);
      expect(await read(field), before);
      expect(await revision(), 1);
      await database.customStatement(
        'DROP TRIGGER reject_settings_backup_revision',
      );
      expect(await remove(), true);
      expect(await revision(), 2);
      expect(await remove(), false);
      expect(await revision(), 2);
    });
  }

  test(
    'a failed Electrum batch rolls back its rows and earlier revisions',
    () async {
      final repository = ElectrumServerStorageDatasource(sqlite: database);
      final before = await read('electrum servers');
      await database.customStatement('''
      CREATE TRIGGER reject_second_backup_revision
      BEFORE UPDATE OF local_revision ON wallet_backup_states
      WHEN NEW.local_revision = 2
      BEGIN SELECT RAISE(ABORT, 'injected second revision failure'); END
    ''');
      await expectLater(
        repository.storeBatch([
          for (final name in ['first', 'second'])
            ElectrumServerModel(
              url: 'ssl://$name.example.invalid:50002',
              network: ElectrumServerNetwork.bitcoinMainnet,
              isCustom: true,
            ),
        ]),
        throwsA(isA<Exception>()),
      );
      expect(await read('electrum servers'), before);
      expect(await revision(), 0);
    },
  );
}
