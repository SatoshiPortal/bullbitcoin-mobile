import 'package:primitives/primitives.dart' show Ok, Err;
import 'package:drift/drift.dart' show Value;
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart'
    show ElectrumFailure, ElectrumSaveFailure;

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
