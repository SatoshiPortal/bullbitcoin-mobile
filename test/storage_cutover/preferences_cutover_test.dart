import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:bull_recoverbull/bull_recoverbull.dart'
    show recoverBullDefaultServerUrl;
import 'package:bull_recoverbull/migration.dart'
    show readLegacyRecoverBullPermission;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:preferences/migration.dart';
import 'package:preferences/preferences.dart';
import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart' show sqlite3;

import '../../packages/legacy_storage/test/migrations_test/bull_database/generated/schema_v15.dart'
    as v15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const customServer = 'http://custom.onion';
  for (final (name, delayed, legacyUrl, standaloneState, expectedPermission) in [
    (
      'late activation preserves consent for the default v16 server',
      true,
      recoverBullDefaultServerUrl,
      null,
      true,
    ),
    (
      'late activation discards consent for a custom v16 server',
      true,
      customServer,
      null,
      false,
    ),
    (
      'published v15 upgrades and an uninitialized v1 falls back to v16',
      false,
      recoverBullDefaultServerUrl,
      (recoverBullDefaultServerUrl, 0, 0),
      true,
    ),
    (
      'initialized v1 preserves default-server consent over a custom v16 server',
      false,
      customServer,
      (recoverBullDefaultServerUrl, 1, 1),
      true,
    ),
    (
      'initialized v1 denies custom-server consent without falling back to v16',
      false,
      recoverBullDefaultServerUrl,
      (customServer, 1, 1),
      false,
    ),
    (
      'initialized v1 denial takes precedence over v16 consent',
      false,
      recoverBullDefaultServerUrl,
      (recoverBullDefaultServerUrl, 0, 1),
      false,
    ),
  ]) {
    test(name, () async {
      final directory = await Directory.systemTemp.createTemp(
        'preferences-upgrade-',
      );
      final source = File('${directory.path}/legacy.sqlite');
      final file = File('${directory.path}/preferences.sqlite');
      final standalone = File('${directory.path}/recoverbull.sqlite');
      if (standaloneState case (final server, final granted, final complete)) {
        final fixture = sqlite3.open(standalone.path);
        try {
          fixture.userVersion = 1;
          fixture.execute(
            'CREATE TABLE recoverbull_state ('
            'id INTEGER NOT NULL DEFAULT 1 PRIMARY KEY CHECK (id = 1), '
            "server TEXT NOT NULL DEFAULT '$recoverBullDefaultServerUrl', "
            'permission_granted INTEGER NOT NULL DEFAULT 0 '
            'CHECK (permission_granted IN (0, 1)), '
            'monitoring_enabled INTEGER NOT NULL DEFAULT 1 '
            'CHECK (monitoring_enabled IN (0, 1)), '
            'legacy_import_complete INTEGER NOT NULL DEFAULT 0 '
            'CHECK (legacy_import_complete IN (0, 1)), '
            'monitoring_revision INTEGER NOT NULL DEFAULT 0, '
            'generation INTEGER NOT NULL DEFAULT 0 CHECK (generation >= 0))',
          );
          fixture.execute(
            'INSERT INTO recoverbull_state '
            '(id, server, permission_granted, legacy_import_complete) '
            'VALUES (1, ?, ?, ?)',
            [server, granted, complete],
          );
        } finally {
          fixture.close();
        }
      }
      FakeSecureStoragePlatform().install();
      final keys = Secrets(scratchDirectory: () async => directory.path)
          .databaseKeys(module: 'preferences');
      final sourceStore = LegacySourceStore(
        source: LegacySource(source, 16),
        create: SqliteDatabase.new,
      );
      final foreground = PreferencesImport(
        file: file,
        defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
        testingKeys: keys,
        readStandalonePermission: () async =>
            (await readLegacyRecoverBullPermission(standalone))
                .mapErr((_) => const LegacyImportUnavailable()),
      );
      final background = PreferencesImport(
        file: file,
        defaultRecoverBullServerUrl: recoverBullDefaultServerUrl,
        testingKeys: keys,
      );
      StorageCutover coordinator(List<LegacyImportParticipant> participants) =>
          StorageCutover(
            directory: Directory('${directory.path}/coordination'),
            legacy: sourceStore,
            expectedOwners: splitV1Owners,
            participants: participants,
          );
      if (delayed) {
        final initial =
            (await coordinator([]).prepare()
                    as Ok<RuntimeAdmission, LegacyImportFailure>)
                .value;
        final db = await sourceStore.open(initial);
        await db.customStatement(
          "UPDATE settings SET currency='CAD',environment='testnet',is_superuser=1,is_dev_mode_enabled=1",
        );
        await db.customStatement(
          'UPDATE recoverbull SET url=?,is_permission_granted=1',
          [legacyUrl],
        );
        await db.customStatement(
          "UPDATE sqlite_sequence SET seq=70 WHERE name='settings'",
        );
        await db.customStatement(
          "UPDATE sqlite_sequence SET seq=80 WHERE name='recoverbull'",
        );
        await initial.close();
      } else {
        final old = v15.DatabaseAtV15(NativeDatabase(source));
        await old.customStatement(
          "INSERT INTO settings (id,environment,bitcoin_unit,language,currency,hide_amounts,is_superuser,is_dev_mode_enabled,use_tor_proxy,tor_proxy_port,tor_transport_mode,last_successful_tor_transport,theme_mode,is_error_reporting_enabled,screen_capture_protection_enabled) VALUES (1,'testnet','sats','unitedStatesEnglish','CAD',1,1,1,0,9050,'automatic',NULL,'system',0,1)",
        );
        await old.customStatement('INSERT INTO recoverbull VALUES (1,?,1)', [
          legacyUrl,
        ]);
        await old.customStatement(
          "UPDATE sqlite_sequence SET seq=70 WHERE name='settings'",
        );
        await old.customStatement(
          "UPDATE sqlite_sequence SET seq=80 WHERE name='recoverbull'",
        );
        await old.close();
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        // First launch prepares; a worker only admits existing state.
        final result = attempt == 0
            ? await coordinator([foreground]).prepare()
            : await coordinator([background]).admit();
        expect(result, isA<Ok>());
        final runtime =
            (result as Ok<RuntimeAdmission, LegacyImportFailure>).value;
        final db = await sourceStore.open(runtime);
        final opened = await PreferencesTesting.open(
          file: file,
          admission: runtime,
          legacyDatabase: db,
          keys: keys,
        );
        expect(opened, isA<Ok>());
        final preferences =
            (opened as Ok<Preferences, PreferencesFailure>).value;
        expect(
          await preferences.recoverBull.read(),
          isA<Ok<bool?, PreferencesFailure>>().having(
            (result) => result.value,
            'normal permission for the default server',
            expectedPermission,
          ),
        );
        expect(
          await preferences.recoverBull.read(regtest: true),
          isA<Ok<bool?, PreferencesFailure>>().having(
            (result) => result.value,
            'regtest permission does not import normal consent',
            false,
          ),
        );
        expect(
          (await preferences.readCurrency() as Ok<String, PreferencesFailure>)
              .value,
          attempt == 0 ? 'CAD' : 'EUR',
        );
        expect(
          (await preferences.readActiveEnvironment()
                  as Ok<Environment, PreferencesFailure>)
              .value,
          attempt == 0 ? Environment.testnet : Environment.mainnet,
        );
        if (attempt == 0) {
          expect(await preferences.setCurrency('EUR'), isA<Ok>());
          expect(
            await preferences.setEnvironment(Environment.mainnet),
            isA<Ok>(),
          );
        }
        expect(
          (await db
                  .customSelect('SELECT environment FROM settings')
                  .getSingle())
              .read<String>('environment'),
          'testnet',
        );
        final executor = await keys.open(
          name: 'main',
          file: file,
          existingSchemaVersion: 1,
        );
        final probe = _Probe(
          (executor as Ok<QueryExecutor, DatabaseOpenFailure>).value,
        );
        runtime.track(probe.close);
        expect(
          (await probe
                  .customSelect(
                    'SELECT name,seq FROM sqlite_sequence ORDER BY name',
                  )
                  .get())
              .map((r) => r.data.values.toList())
              .toList(),
          [
            ['recoverbull', 80],
            ['settings', 70],
          ],
        );
        expect(
          (await probe
                  .customSelect('SELECT id FROM legacy_import_receipts')
                  .getSingle())
              .read<String>('id'),
          'split-v1/preferences',
        );
        expect(
          (await probe.customSelect('PRAGMA table_info(settings)').get())
              .length,
          17,
        );
        await preferences.close();
        await runtime.close();
      }
      expect(source.existsSync(), isTrue);
      await directory.delete(recursive: true);
    });
  }
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo> get allTables => const [];
}
