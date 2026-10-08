import 'dart:io';

import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/recoverbull_setup.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Documents extends PathProviderPlatform {
  final String path;

  _Documents(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

class _Settings extends Mock implements SettingsRepository {}

class _Wallets extends Mock implements WalletRepository {}

class _Seeds extends Mock implements SeedRepository {}

class _DefaultWallets extends Mock implements CreateDefaultWalletsUsecase {}

class _Tor extends Mock implements Tor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

void main() {
  SqliteDatabase database() => SqliteDatabase(NativeDatabase.memory());

  test(
    'migration matrix distinguishes absent, empty, and invalid URLs',
    () async {
      final absent = database();
      await absent.customStatement('DELETE FROM recoverbull');
      expect(
        (await readRecoverBullLegacySettings(absent)).wasImported,
        isFalse,
      );
      await absent.close();

      final empty = database();
      await empty
          .into(empty.recoverbull)
          .insert(
            RecoverbullCompanion.insert(url: '', isPermissionGranted: false),
          );
      expect((await readRecoverBullLegacySettings(empty)).serverUrl, isNull);
      await empty.close();

      final invalid = database();
      await invalid
          .into(invalid.recoverbull)
          .insert(
            RecoverbullCompanion.insert(
              url: 'not a recoverbull server',
              isPermissionGranted: false,
            ),
          );
      expect((await readRecoverBullLegacySettings(invalid)).serverUrl, isNull);
      await invalid.close();
    },
  );

  test('migration reports an unreadable legacy database for retry', () async {
    final legacy = database();
    var reported = false;
    await legacy.customStatement('DROP TABLE recoverbull');

    final settings = await readRecoverBullLegacySettings(
      legacy,
      onReadFailure: () => reported = true,
    );

    expect(settings.readFailed, isTrue);
    expect(reported, isTrue);
  });

  test(
    'migration can be replayed without overwriting package settings',
    () async {
      final package = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await package.ensureState(
        initialServerUrlOverride: 'http://existing.onion',
      );
      await package.ensureState(
        initialServerUrlOverride: 'http://legacy.onion',
      );

      final state = await package.select(package.recoverbullState).getSingle();
      expect(state.serverUrlOverride, 'http://existing.onion');
      await package.close();
    },
  );

  test('app startup continues with RecoverBull unavailable when its database '
      'cannot be opened', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final documents = await Directory.systemTemp.createTemp(
      'recoverbull-setup-',
    );
    addTearDown(() => documents.delete(recursive: true));
    // A directory where the database file belongs is not corruption, so
    // the package cannot recover from it by archiving.
    await Directory('${documents.path}/recoverbull.sqlite').create();
    final previousPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Documents(documents.path);
    addTearDown(() => PathProviderPlatform.instance = previousPathProvider);
    final tor = _Tor();
    when(() => tor.embedded).thenReturn(_EmbeddedTor());
    final locator = GetIt.asNewInstance()
      ..registerSingleton<SettingsRepository>(_Settings())
      ..registerSingleton<WalletRepository>(_Wallets())
      ..registerSingleton<SeedRepository>(_Seeds())
      ..registerSingleton<CreateDefaultWalletsUsecase>(_DefaultWallets())
      ..registerSingleton<Tor>(tor)
      ..registerSingleton<TorRoutePool>(TorRoutePool());
    final legacy = database();
    addTearDown(legacy.close);

    await RecoverBullSetup.setup(
      locator,
      database: legacy,
      startAttemptMonitoring: true,
    );

    final feature = locator<RecoverBullFeature>();
    expect((await feature.status()).isKnown, isFalse);
    expect(await feature.checkService(), RecoverBullHealth.offline);
    expect(feature.attemptMonitoring.enabled, isFalse);
    expect(
      feature.routes.whereType<GoRoute>().map((route) => route.name),
      containsAll([
        for (final route in RecoverBullRoute.values) route.name,
        for (final route in RecoverBullGoogleDriveRoute.values) route.name,
      ]),
    );
    await locator<RecoverBullLifecycle>().dispose();
  });
}
