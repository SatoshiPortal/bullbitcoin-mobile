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

      await AppLocator.setup(
        locator,
        database,
        payjoinDatabasePath: '${directory.path}/payjoin.sqlite',
        startPayjoinRecovery: false,
        startOrderSwapWatcher: false,
        startAutoswapWatcher: false,
      );
      composed = true;
      expect(nativeTor.calls, 1);
      expect(locator<WalletRepository>(), isA<WalletRepository>());
    },
  );
}
