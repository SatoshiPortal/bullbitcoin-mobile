import 'package:labels/testing.dart';
import 'package:electrum/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart' as wallet;
import 'package:bb_mobile/features/transactions/public/transactions_facade.dart';

import 'dart:io';

import 'package:bb_mobile/core_locator.dart';
import 'package:bb_mobile/features/settings/settings_core_locator.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/wallet/wallet_core_locator.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/setup.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:secrets/secrets.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/preferences_database.dart';

class _NativeTor implements TorNativeInitializer {
  int calls = 0;

  @override
  Future<void> initialize() async {
    calls++;
  }
}

final class _Picker extends FilePickerPlatform {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FilePickerPlatform.instance = _Picker();

  test(
    'foreground RecoverBull mounts with the owning modules registrations',
    () async {
      final services = GetIt.asNewInstance();
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-composition-',
      );
      final database = SqliteDatabase(NativeDatabase.memory());
      final owner = await createPreferencesDatabase();
      await owner.customStatement('INSERT INTO recoverbull VALUES (1, 0)');
      addTearDown(() async {
        await services.reset();
        await owner.close();
        await database.close();
        await directory.delete(recursive: true);
      });
      CoreLocator.register(services, database);
      services.registerLazySingleton<Secrets>(
        () => Secrets(scratchDirectory: () async => directory.path),
      );
      await SettingsLocator.registerRepositories(
        services,
        PreferencesTesting.fromDatabases(owner: owner, legacy: database),
      );
      // Replace native initialization through the published host seam; keep
      // the real backend, repository and owner registrations.
      final nativeTor = _NativeTor();
      services.registerSingleton<TorNativeInitializer>(nativeTor);
      await TorLocator.registerDatasources(services);
      expect(nativeTor.calls, 1);
      TorLocator.registerRepositories(services);
      TorLocator.registerUsecases(services);
      CoreLocator.setupElectrum(
        services,
        createElectrumForTesting(
          database: database,
          readPreferences: () =>
              services<Preferences>().readConnectionPreferences(),
          tor: () => services<Tor>(),
        ),
      );
      await WalletLocator.registerDatasources(services);
      WalletLocator.registerRepositories(services);
      WalletLocator.registerUsecases(services);
      final walletSync = WalletLocator.syncAccess(services);
      setupLabels(
        services,
        createLabelsForTesting(
          database: database,
          sync: walletSync.foreground,
          openWallet: walletSync.openWallet,
        ),
      );
      // Wallet's native runtime requires the Payjoin owner's reservation port.
      PayjoinSetup.setup(services, startRecovery: false);
      wallet.WalletLocator.setup(services);

      expect(services.isRegistered<EmbeddedTor>(), isFalse);
      final gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
      final admission = await gate.acquire(
        exclusive: false,
        timeout: const Duration(seconds: 2),
      ) as RuntimeAdmission;
      services.registerSingleton<RuntimeAdmission>(
        admission,
        dispose: (value) => value.close(),
      );
      services.registerSingleton(
        RecoverBullCutover(
          file: File('${directory.path}/encrypted.sqlite'),
          standalone: File('${directory.path}/recoverbull.sqlite'),
          regtest: false,
        ),
      );
      await AppLocator.setupRecoverBull(
        services,
        databasePath: '${directory.path}/recoverbull.sqlite',
      );
      final standalone = sqlite3.open('${directory.path}/recoverbull.sqlite');
      try {
        standalone.execute(
          "UPDATE recoverbull_state SET server='http://obsolete.onion', "
          'permission_granted=1, legacy_import_complete=1',
        );
      } finally {
        standalone.close();
      }

      expect(
        services<RecoverBullFacade>(),
        same(services<RecoverBullFeature>().facade),
      );
      expect(
        await services<RecoverBullFacade>().settings(),
        isA<Ok<BackupSettings, RecoverBullFailure>>()
            .having(
              (result) => result.value.server.toString(),
              'server',
              SettingsConstants.recoverbullUrl,
            )
            .having(
              (result) => result.value.permissionGranted,
              'permission',
              isFalse,
            ),
      );
      final facade = services<RecoverBullFacade>();
      expect(
        await facade.acceptServer(Uri.parse('http://obsolete.onion')),
        isA<Err<BackupSettings, RecoverBullFailure>>(),
      );
      expect(
        await facade.acceptServer(Uri.parse(SettingsConstants.recoverbullUrl)),
        isA<Ok<BackupSettings, RecoverBullFailure>>().having(
          (result) => result.value.permissionGranted,
          'permission',
          isTrue,
        ),
      );
      expect(
        (await owner
                .customSelect(
                  'SELECT is_permission_granted, revision '
                  'FROM recoverbull_permission_overrides',
                )
                .getSingle())
            .data,
        {'is_permission_granted': 1, 'revision': 1},
      );
      final granted = await facade.settings();
      expect(
        await facade.acceptServer(Uri.parse(SettingsConstants.recoverbullUrl)),
        isA<Ok>(),
      );
      final grantedAgain = await facade.settings();
      final before = (granted as Ok<BackupSettings, RecoverBullFailure>).value;
      final after =
          (grantedAgain as Ok<BackupSettings, RecoverBullFailure>).value;
      expect(after.generation, before.generation);
      expect(after.sameGeneration(before), isFalse);
      final preserved = sqlite3.open('${directory.path}/recoverbull.sqlite');
      try {
        expect(
          preserved
              .select(
                'SELECT server, permission_granted, generation '
                'FROM recoverbull_state',
              )
              .single,
          {
            'server': 'http://obsolete.onion',
            'permission_granted': 1,
            'generation': before.generation,
          },
        );
      } finally {
        preserved.close();
      }
      expect(
        services<RecoverBullRoutePort>(),
        same(services<RecoverBullEnvironmentPort>()),
      );
      expect(services<RecoverBullWalletPort>(), isNotNull);
    },
  );
}
