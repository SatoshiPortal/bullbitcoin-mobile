import 'package:labels/testing.dart';
import 'package:electrum/testing.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:bb_mobile/features/wallet/wallet_locator.dart' as wallet;
import 'package:transactions/setup.dart';

import 'dart:io';

import 'package:bb_mobile/core_locator.dart';
import 'package:settings/setup.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bb_mobile/features/wallet/wallet_core_locator.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/native_runtime_setup.dart';
import 'package:overview/setup.dart' show OverviewSynchronization;
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/migration.dart'
    show readLegacyRecoverBullPermission;
import 'package:bull_recoverbull/testing.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/setup.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:preferences/migration.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import 'support/inventory_fixture.dart';

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

  for (final hasStandalone in [false, true]) {
    test(
      hasStandalone
          ? 'RecoverBull keeps obsolete standalone consent out of Preferences'
          : 'RecoverBull keeps v16 consent without a standalone database',
      () async {
        final services = GetIt.asNewInstance();
        final directory = await Directory.systemTemp.createTemp(
          'recoverbull-composition-',
        );
        InventoryFixture? inventory;
        addTearDown(() async {
          await services.reset();
          await inventory?.close();
          await directory.delete(recursive: true);
        });
        FakeSecureStoragePlatform().install();
        inventory = await InventoryFixture.compose(directory, services);
        final sourceFile = File('${directory.path}/bullbitcoin_sqlite.sqlite');
        final standalone = File('${directory.path}/recoverbull.sqlite');
        final ownerFile = File('${directory.path}/recoverbull-owner.sqlite');
        final preferencesFile = File('${directory.path}/preferences.sqlite');
        final source = SqliteDatabase(NativeDatabase(sourceFile));
        try {
          await source.customStatement(
            'UPDATE recoverbull SET url=?, is_permission_granted=1',
            [recoverBullDefaultServerUrl],
          );
        } finally {
          await source.close();
        }
        if (hasStandalone) {
          final legacyOwner = openRecoverBullDatabaseForTesting(
            standalone.path,
          );
          try {
            await legacyOwner.forceOpen();
            await legacyOwner.customStatement(
              "UPDATE recoverbull_state SET server='http://obsolete.onion', "
              'permission_granted=1, legacy_import_complete=1',
            );
            await legacyOwner.customStatement('PRAGMA user_version = 1');
          } finally {
            await legacyOwner.close();
          }
        }
        final secrets = Secrets(
          authority: unlockedSessionAuthority(),
          scratchDirectory: () async => directory.path,
        );
        final keys = secrets.databaseKeys(module: 'preferences');
        final recoverBull = recoverBullCutoverForTesting(
          file: ownerFile,
          standalone: standalone,
        );
        final legacy = LegacySourceStore(
          source: LegacySource(sourceFile, SqliteDatabase.currentSchemaVersion),
          create: SqliteDatabase.new,
        );
        final prepared = await StorageCutover(
          directory: Directory('${directory.path}/coordination'),
          legacy: legacy,
          expectedOwners: const {'preferences', 'recoverbull'},
          participants: [
            PreferencesImport(
              file: preferencesFile,
              defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
              readStandalonePermission: () async =>
                  (await readLegacyRecoverBullPermission(standalone))
                      .mapErr((_) => const LegacyImportUnavailable()),
              testingKeys: keys,
            ),
            recoverBull.participant,
          ],
        ).prepare();
        final admission = prepared.fold(
          (value) => value,
          (failure) => fail('Cutover failed: ${failure.runtimeType}'),
        );
        services.registerSingleton<RuntimeAdmission>(
          admission,
          dispose: (value) => value.close(),
        );
        services.registerSingleton(recoverBull);
        final database = await legacy.open(admission);
        final preferences =
            (await PreferencesTesting.open(
              file: preferencesFile,
              admission: admission,
              keys: keys,
            )).fold(
              (value) => value,
              (failure) =>
                  fail('Preferences open failed: ${failure.runtimeType}'),
            );
        services.registerSingleton<Secrets>(secrets);
        await SettingsLocator.registerRepositories(services, preferences);
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
        mountPayjoin(services, startRecovery: false);
        registerNativeRuntime(
          services,
          overview: () => services<OverviewSynchronization>(),
        );
        wallet.WalletLocator.setup(services);

        expect(services.isRegistered<EmbeddedTor>(), isFalse);
        await AppLocator.setupRecoverBull(
          services,
          databasePath: standalone.path,
        );

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
                recoverBullDefaultServerUrl,
              )
              .having(
                (result) => result.value.permissionGranted,
                'permission',
                !hasStandalone,
              ),
        );
        final facade = services<RecoverBullFacade>();
        expect(
          await facade.acceptServer(Uri.parse('http://obsolete.onion')),
          isA<Err<BackupSettings, RecoverBullFailure>>(),
        );
        expect(
          await facade.acceptServer(Uri.parse(recoverBullDefaultServerUrl)),
          isA<Ok<BackupSettings, RecoverBullFailure>>().having(
            (result) => result.value.permissionGranted,
            'permission',
            isTrue,
          ),
        );
        expect(
          await preferences.recoverBull.readState(),
          isA<Ok<({bool granted, int revision})?, PreferencesFailure>>().having(
            (result) => result.value,
            'live consent',
            (granted: true, revision: 1),
          ),
        );
        final granted = await facade.settings();
        expect(
          await facade.acceptServer(Uri.parse(recoverBullDefaultServerUrl)),
          isA<Ok>(),
        );
        final grantedAgain = await facade.settings();
        final before =
            (granted as Ok<BackupSettings, RecoverBullFailure>).value;
        final after =
            (grantedAgain as Ok<BackupSettings, RecoverBullFailure>).value;
        expect(after.generation, before.generation);
        expect(after.sameGeneration(before), isFalse);
        if (hasStandalone) {
          final preserved = sqlite3.open(standalone.path);
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
        } else {
          expect(standalone.existsSync(), isFalse);
        }
        final persisted = sqlite3.open(ownerFile.path);
        try {
          expect(
            persisted
                .select('SELECT permission_granted FROM recoverbull_state')
                .single['permission_granted'],
            0,
          );
        } finally {
          persisted.close();
        }
        expect(
          services<RecoverBullRoutePort>(),
          same(services<RecoverBullEnvironmentPort>()),
        );
        expect(services<RecoverBullWalletPort>(), isNotNull);
      },
    );
  }
}
