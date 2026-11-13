import 'dart:io';

import 'package:bb_mobile/core/core_locator.dart';
import 'package:bb_mobile/core/electrum/frameworks/di/electrum_locator.dart';
import 'package:bb_mobile/core/settings/settings_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/wallet_locator.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:secrets/secrets.dart';

class _NativeTor implements TorNativeInitializer {
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls++;
  }
}

final class _Picker extends FilePicker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FilePicker.platform = _Picker();

  test(
    'foreground RecoverBull mounts with the owning modules registrations',
    () async {
      final services = GetIt.asNewInstance();
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-composition-',
      );
      final database = SqliteDatabase(NativeDatabase.memory());
      addTearDown(() async {
        await services.reset();
        await database.close();
        await directory.delete(recursive: true);
      });
      CoreLocator.register(services, database);
      services.registerLazySingleton<Secrets>(
        () => Secrets(scratchDirectory: () async => directory.path),
      );
      await SettingsLocator.registerDatasources(services);
      await SettingsLocator.registerRepositories(services);
      // Replace native initialization through the published host seam; keep
      // the real backend, repository and owner registrations.
      final nativeTor = _NativeTor();
      services.registerSingleton<TorNativeInitializer>(nativeTor);
      await TorLocator.registerDatasources(services);
      expect(nativeTor.calls, 1);
      TorLocator.registerRepositories(services);
      TorLocator.registerUsecases(services);
      await ElectrumLocator.registerDatasources(services);
      ElectrumLocator.registerRepositories(services);
      ElectrumLocator.registerPorts(services);
      await WalletLocator.registerDatasources(services);
      WalletLocator.registerRepositories(services);
      WalletLocator.registerUsecases(services);

      expect(services.isRegistered<EmbeddedTor>(), isFalse);
      await AppLocator.setupRecoverBull(
        services,
        databasePath: '${directory.path}/recoverbull.sqlite',
      );

      expect(
        services<RecoverBullFacade>(),
        same(services<RecoverBullFeature>().facade),
      );
      expect(
        services<RecoverBullRoutePort>(),
        same(services<RecoverBullEnvironmentPort>()),
      );
      expect(services<RecoverBullWalletPort>(), isNotNull);
    },
  );
}
