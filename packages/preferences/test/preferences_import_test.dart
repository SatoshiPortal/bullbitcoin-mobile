import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:preferences/migration.dart';
import 'package:preferences/src/data/preferences_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

const _columns =
    'id,environment,bitcoin_unit,start_amounts_in_fiat,language,currency,hide_amounts,is_superuser,is_dev_mode_enabled,use_tor_proxy,tor_proxy_port,tor_transport_mode,last_successful_tor_transport,theme_mode,is_error_reporting_enabled,screen_capture_protection_enabled';
const _defaultServer = 'http://default.onion';
const _values = [
  7,
  'future-network',
  'future-unit',
  1,
  '',
  'CAD',
  1,
  0,
  0,
  1,
  9090,
  'future-transport',
  null,
  'future-theme',
  0,
  0,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final childDirectory = Platform.environment['S1B_PREFERENCES_DIRECTORY'];
  if (childDirectory != null) {
    test('crash child', () async {
      final directory = Directory(childDirectory);
      final entries = (jsonDecode(
        await File('${directory.path}/fixture-keystore.json').readAsString(),
      ) as Map<String, dynamic>).cast<String, String>();
      FakeSecureStoragePlatform(entries: entries).install();
      final keys = Secrets(scratchDirectory: () async => directory.path)
          .databaseKeys(module: 'preferences');
      final lease = await NativeFileGate(
        File('${directory.path}/gate'),
      ).acquire(exclusive: true, timeout: Duration.zero) as ExclusiveAdmission;
      final step = Platform.environment['S1B_PREFERENCES_STEP'];
      final result = await PreferencesImport(
        file: File('${directory.path}/preferences.sqlite'),
        defaultRecoverBullServerUrl: _defaultServer,
        testingKeys: keys,
        checkpoint: (current) async {
          if (current == step) {
            final partial = File('${directory.path}/checkpoint.tmp');
            await partial.writeAsString('$pid', flush: true);
            await partial.rename('${directory.path}/checkpoint');
            await Completer<void>().future;
          }
        },
      ).prepare(lease, OwnerOrigin.legacy);
      final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
      if (step?.startsWith('fresh') ?? false) {
        expect(await owner.initializeFresh(), isA<Ok>());
      } else {
        expect(
          await owner.importLegacy(
            LegacySource(File('${directory.path}/legacy.sqlite'), 16),
          ),
          isA<Ok>(),
        );
      }
      await lease.close();
    });
    return;
  }
  late Directory directory;
  late FakeSecureStoragePlatform keystore;
  late DatabaseKeys keys;
  late NativeFileGate gate;
  late File destination;
  late LegacySource source;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('preferences-import-');
    keystore = FakeSecureStoragePlatform()..install();
    keys = Secrets(scratchDirectory: () async => directory.path)
        .databaseKeys(module: 'preferences');
    gate = NativeFileGate(File('${directory.path}/gate'));
    destination = File('${directory.path}/preferences.sqlite');
    source = LegacySource(File('${directory.path}/legacy.sqlite'), 16);
  });
  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });
  PreferencesImport participant({
    Future<void> Function(String)? checkpoint,
    Future<
      Result<({String sourceUrl, bool permissionGranted})?, LegacyImportFailure>
    >
    Function()?
    readPermission,
  }) => PreferencesImport(
    file: destination,
    defaultRecoverBullServerUrl: _defaultServer,
    testingKeys: keys,
    checkpoint: checkpoint,
    readStandalonePermission: readPermission,
  );
  Future<ExclusiveAdmission> exclusive() async =>
      await gate.acquire(exclusive: true, timeout: Duration.zero)
          as ExclusiveAdmission;
  Future<PreparedOwner> prepare(
    ExclusiveAdmission admission, {
    Future<void> Function(String)? checkpoint,
  }) async => (await participant(checkpoint: checkpoint).prepare(
    admission,
    OwnerOrigin.legacy,
  ) as Ok<PreparedOwner, LegacyImportFailure>).value;
  Future<PreferencesStore> open(LifecycleAdmission admission) async =>
      (await PreferencesStore.open(
        destination,
        admission,
        existing: true,
        testingKeys: keys,
      ) as Ok<PreferencesStore, DatabaseOpenFailure>).value;

  void legacy({bool empty = false, bool deleted = false}) {
    final db = sqlite3.open(source.file.path);
    db.execute(
      'CREATE TABLE settings (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'environment TEXT NOT NULL, bitcoin_unit TEXT NOT NULL, start_amounts_in_fiat INTEGER NOT NULL, '
      'language TEXT NOT NULL, currency TEXT NOT NULL, hide_amounts INTEGER NOT NULL, '
      'is_superuser INTEGER NOT NULL, is_dev_mode_enabled INTEGER NOT NULL, use_tor_proxy INTEGER NOT NULL, '
      'tor_proxy_port INTEGER NOT NULL, tor_transport_mode TEXT NOT NULL, last_successful_tor_transport TEXT, '
      'theme_mode TEXT NOT NULL, is_error_reporting_enabled INTEGER NOT NULL, screen_capture_protection_enabled INTEGER NOT NULL, '
      'exchange_testnet_basic_auth_username TEXT, exchange_testnet_basic_auth_password TEXT)',
    );
    db.execute(
      'CREATE TABLE recoverbull (id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT NOT NULL, is_permission_granted INTEGER NOT NULL)',
    );
    if (!empty || deleted) {
      db.execute(
        'INSERT INTO settings ($_columns) VALUES (${List.filled(16, '?').join(',')})',
        _values,
      );
      db.execute(
        "INSERT INTO recoverbull VALUES (9, 'VERBATIM:not-normalized', 1)",
      );
      db.execute(
        'INSERT INTO settings ($_columns) VALUES (${List.filled(16, '?').join(',')})',
        [90, ..._values.skip(1)],
      );
      db.execute('DELETE FROM settings WHERE id = 90');
      db.execute("INSERT INTO recoverbull VALUES (120, 'deleted', 0)");
      db.execute('DELETE FROM recoverbull WHERE id = 120');
    }
    if (empty) {
      db.execute('DELETE FROM settings');
      db.execute('DELETE FROM recoverbull');
    }
    db.userVersion = 16;
    db.close();
  }

  for (final mode in ['rows', 'never-written', 'deleted-all']) {
    test('raw import and both sequence states survive: $mode', () async {
      legacy(empty: mode != 'rows', deleted: mode == 'deleted-all');
      final before = source.file.readAsBytesSync();
      final lease = await exclusive();
      final owner = await prepare(lease);
      expect(await owner.importLegacy(source), isA<Ok>());
      final store = await open(lease);
      final rows = await store.database
          .customSelect('SELECT $_columns FROM settings')
          .get();
      final recoverbull = await store.database
          .customSelect('SELECT * FROM recoverbull')
          .get();
      expect(
        rows.map((row) => row.data.values.toList()).toList(),
        mode == 'rows' ? [_values] : [],
      );
      expect(
        recoverbull.map((row) => row.data.values.toList()).toList(),
        mode == 'rows'
            ? [
                [9, 0],
              ]
            : [],
      );
      final sequences = await store.database
          .customSelect('SELECT name,seq FROM sqlite_sequence ORDER BY name')
          .get();
      expect(
        sequences.map((row) => row.data.values.toList()).toList(),
        mode == 'never-written'
            ? []
            : [
                ['recoverbull', 120],
                ['settings', 90],
              ],
      );
      expect(source.file.readAsBytesSync(), before);
      // Receipt replay does not reopen a missing source.
      await source.file.delete();
      expect(await owner.importLegacy(source), isA<Ok>());
      await lease.close();
    });
  }

  for (final permission in <bool?>[true, false, null]) {
    test(
      'standalone permission $permission takes precedence only if present',
      () async {
        legacy();
        final original = source.file.readAsBytesSync();
        var reads = 0;
        final lease = await exclusive();
        final result = await participant(
          readPermission: () async {
            reads++;
            return Ok(
              permission == null
                  ? null
                  : (sourceUrl: _defaultServer, permissionGranted: permission),
            );
          },
        ).prepare(lease, OwnerOrigin.legacy);
        final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
        expect(await owner.importLegacy(source), isA<Ok>());
        expect(await owner.importLegacy(source), isA<Ok>());
        expect(reads, 1);
        final store = await open(lease);
        final overrides = await store.database
            .customSelect('SELECT * FROM recoverbull_permission_overrides')
            .get();
        expect(
          overrides.map((row) => row.data.values.toList()).toList(),
          permission == null
              ? []
              : [
                  ['default', permission ? 1 : 0, 0],
                ],
        );
        final definition = await store.database
            .customSelect('PRAGMA table_info(recoverbull)')
            .get();
        expect(definition.map((row) => row.read<String>('name')), [
          'id',
          'is_permission_granted',
        ]);
        expect(source.file.readAsBytesSync(), original);
        await lease.close();
      },
    );
  }

  test('deferred standalone consent preserves the failure and rolls back the import', () async {
    legacy();
    final lease = await exclusive();
    final result = await participant(
      readPermission: () async => const Err(LegacyImportDeferred()),
    ).prepare(lease, OwnerOrigin.legacy);
    final owner = (result as Ok<PreparedOwner, LegacyImportFailure>).value;
    expect(
      await owner.importLegacy(source),
      isA<Err<void, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyImportDeferred>(),
      ),
    );
    final store = await open(lease);
    for (final table in [
      'settings',
      'recoverbull',
      'recoverbull_permission_overrides',
      'sqlite_sequence',
      'legacy_import_receipts',
    ]) {
      expect(
        await store.database.customSelect('SELECT * FROM $table').get(),
        isEmpty,
      );
    }
    await lease.close();
  });

  for (final table in ['settings', 'recoverbull']) {
    test('$table next allocation and replay never reuse deleted high-water', () async {
      legacy(empty: true, deleted: true);
      final lease = await exclusive();
      final owner = await prepare(lease);
      expect(await owner.importLegacy(source), isA<Ok>());
      final store = await open(lease);
      if (table == 'settings') {
        await store.database.customStatement(
          'INSERT INTO settings (${_columns.substring(3)}) VALUES (${List.filled(15, '?').join(',')})',
          _values.skip(1).toList(),
        );
      } else {
        await store.database.customStatement(
          'INSERT INTO recoverbull (is_permission_granted) VALUES (0)',
        );
      }
      final expected = table == 'settings' ? 91 : 121;
      expect(
        (await store.database.customSelect('SELECT id FROM $table').getSingle())
            .read<int>('id'),
        expected,
      );
      await store.database.customStatement('DELETE FROM $table');
      await source.file.delete();
      expect(await owner.importLegacy(source), isA<Ok>());
      final seq = await store.database
          .customSelect("SELECT seq FROM sqlite_sequence WHERE name = '$table'")
          .getSingle();
      expect(seq.read<int>('seq'), expected);
      await lease.close();
    });

    test('$table sequence and rows roll back before receipt commit', () async {
      legacy();
      final lease = await exclusive();
      final owner = await prepare(
        lease,
        checkpoint: (step) async {
          if (step == 'import-sequence-$table') {
            throw const FileSystemException('fixture interruption');
          }
        },
      );
      expect(await owner.importLegacy(source), isA<Err>());
      final store = await open(lease);
      for (final name in [
        'settings',
        'recoverbull',
        'sqlite_sequence',
        'legacy_import_receipts',
      ]) {
        expect(
          await store.database.customSelect('SELECT * FROM $name').get(),
          isEmpty,
        );
      }
      await lease.close();
      final retry = await exclusive();
      expect(await (await prepare(retry)).importLegacy(source), isA<Ok>());
      await retry.close();
    });

    test(
      '$table unreceipted sequence conflict preserves destination',
      () async {
        legacy();
        final lease = await exclusive();
        final owner = await prepare(lease);
        expect(
          await owner.receipt(),
          isA<Ok<OwnerReadiness, LegacyImportFailure>>(),
        );
        final store = await open(lease);
        await store.database.customStatement(
          'INSERT INTO sqlite_sequence(name,seq) VALUES (?,?)',
          [table, 999],
        );
        expect(await owner.importLegacy(source), isA<Err>());
        expect(
          (await store.database
                  .customSelect('SELECT seq FROM sqlite_sequence')
                  .getSingle())
              .read<int>('seq'),
          999,
        );
        expect(
          await store.database
              .customSelect('SELECT * FROM legacy_import_receipts')
              .get(),
          isEmpty,
        );
        await lease.close();
      },
    );
  }

  test(
    'fresh seeds and sequences share a distinct committed receipt',
    () async {
      final lease = await exclusive();
      final owner = await prepare(lease);
      expect(
        await owner.receipt(),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (r) => r.value,
          'pending',
          OwnerReadiness.pending,
        ),
      );
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.initializeFresh(), isA<Ok>());
      final store = await open(lease);
      final settings = await store.database
          .customSelect('SELECT $_columns FROM settings')
          .getSingle();
      expect(settings.data.values.toList(), [
        1,
        'mainnet',
        'sats',
        0,
        'unitedStatesEnglish',
        'USD',
        0,
        0,
        0,
        0,
        9050,
        'automatic',
        null,
        'system',
        0,
        1,
      ]);
      expect(
        (await store.database
                .customSelect('SELECT * FROM recoverbull')
                .getSingle())
            .data
            .values
            .toList(),
        [1, 0],
      );
      expect(
        (await store.database
                .customSelect('SELECT * FROM sqlite_sequence ORDER BY name')
                .get())
            .map((r) => r.data.values.toList()),
        [
          ['recoverbull', 1],
          ['settings', 1],
        ],
      );
      expect(
        (await store.database
                .customSelect('SELECT id FROM legacy_import_receipts')
                .getSingle())
            .read<String>('id'),
        'fresh-v1/preferences',
      );
      await lease.close();
    },
  );

  test(
    'missing owner key fails closed and preserves encrypted family',
    () async {
      final lease = await exclusive();
      expect(await (await prepare(lease)).initializeFresh(), isA<Ok>());
      await lease.close();
      final before = destination.readAsBytesSync();
      keystore.entries.clear();
      final shared = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      expect(await participant().inspect(shared), isA<Err>());
      await shared.close();
      expect(destination.readAsBytesSync(), before);
    },
  );

  test(
    'an unrelated owner key cannot open or replace the encrypted store',
    () async {
      final lease = await exclusive();
      expect(await (await prepare(lease)).initializeFresh(), isA<Ok>());
      await lease.close();
      final before = destination.readAsBytesSync();
      final replacement = FakeSecureStoragePlatform()..install();
      expect(await keys.getOrCreate(name: 'main'), isA<Ok>());
      final shared = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      expect(await participant().inspect(shared), isA<Err>());
      await shared.close();
      expect(destination.readAsBytesSync(), before);
      expect(replacement.entries, hasLength(1));
    },
  );

  test(
    'locked keystore and orphan family cannot provision or publish readiness',
    () async {
      final lease = await exclusive();
      keystore.locked = true;
      expect(
        await participant().prepare(lease, OwnerOrigin.fresh),
        isA<Err<PreparedOwner, LegacyImportFailure>>().having(
          (r) => r.failure,
          'locked',
          isA<LegacyImportDeferred>(),
        ),
      );
      keystore.locked = false;
      File('${destination.path}-wal').writeAsStringSync('orphan');
      expect(await participant().prepare(lease, OwnerOrigin.fresh), isA<Err>());
      expect(destination.existsSync(), isFalse);
      expect(keystore.entries, isEmpty);
      await lease.close();
    },
  );

  test('an unrecognized receipt cannot admit Preferences', () async {
    final lease = await exclusive();
    final owner = await prepare(lease);
    expect(
      await owner.receipt(),
      isA<Ok<OwnerReadiness, LegacyImportFailure>>(),
    );
    final store = await open(lease);
    await store.database.customStatement(
      "INSERT INTO legacy_import_receipts VALUES ('split-v1/other')",
    );
    expect(
      await owner.receipt(),
      isA<Err<OwnerReadiness, LegacyImportFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<LegacyImportVerificationFailed>(),
      ),
    );
    await lease.close();
  });

  test(
    'incompatible receipts are rejected without changing either data set',
    () async {
      final lease = await exclusive();
      final owner = await prepare(lease);
      expect(await owner.initializeFresh(), isA<Ok>());
      final store = await open(lease);
      await store.database.customStatement(
        "INSERT INTO legacy_import_receipts VALUES ('split-v1/preferences')",
      );
      expect(await owner.receipt(), isA<Err>());
      expect(await owner.importLegacy(source), isA<Err>());
      expect(await owner.initializeFresh(), isA<Err>());
      expect(
        (await store.database
                .customSelect('SELECT currency FROM settings')
                .getSingle())
            .read<String>('currency'),
        'USD',
      );
      await lease.close();
    },
  );

  for (final table in ['settings', 'recoverbull']) {
    for (final invalid in ['duplicate', 'non-integer', 'below-row']) {
      test(
        '$table malformed sequence $invalid refuses complete import',
        () async {
          legacy();
          final db = sqlite3.open(source.file.path);
          if (invalid == 'duplicate') {
            db.execute('INSERT INTO sqlite_sequence(name,seq) VALUES (?,?)', [
              table,
              999,
            ]);
          } else {
            db.execute('UPDATE sqlite_sequence SET seq = ? WHERE name = ?', [
              invalid == 'non-integer' ? 'invalid' : 1,
              table,
            ]);
          }
          db.close();
          final lease = await exclusive();
          final owner = await prepare(lease);
          expect(await owner.importLegacy(source), isA<Err>());
          final store = await open(lease);
          for (final name in [
            'settings',
            'recoverbull',
            'sqlite_sequence',
            'legacy_import_receipts',
          ]) {
            expect(
              await store.database.customSelect('SELECT * FROM $name').get(),
              isEmpty,
            );
          }
          await lease.close();
        },
      );
    }
  }

  for (final step in [
    'fresh-schema',
    'fresh-seeds',
    'fresh-receipt',
    'fresh-commit',
    'import-rows-settings',
    'import-sequence-settings',
    'import-rows-recoverbull',
    'import-sequence-recoverbull',
    'import-verify',
    'import-commit',
  ]) {
    test('SIGKILL at $step replays twice with complete sequence state', () async {
      final fresh = step.startsWith('fresh');
      if (!fresh) legacy(empty: true, deleted: true);
      expect(await keys.getOrCreate(name: 'main'), isA<Ok>());
      // Disposable generated fixture key only; removed with the test directory.
      await File('${directory.path}/fixture-keystore.json')
          .writeAsString(jsonEncode(keystore.entries), flush: true);
      final child = await Process.start(
        'fvm',
        [
          'flutter',
          'test',
          'test/preferences_import_test.dart',
          '--no-pub',
          '--reporter',
          'expanded',
        ],
        environment: {
          'S1B_PREFERENCES_DIRECTORY': directory.path,
          'S1B_PREFERENCES_STEP': step,
        },
      );
      final output = child.stdout.transform(utf8.decoder).join();
      final errors = child.stderr.transform(utf8.decoder).join();
      final checkpoint = File('${directory.path}/checkpoint');
      final timer = Stopwatch()..start();
      try {
        while (!checkpoint.existsSync() &&
            timer.elapsed < const Duration(seconds: 90)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        if (!checkpoint.existsSync()) {
          child.kill();
          fail('Child missed checkpoint: ${await output} ${await errors}');
        }
        expect(
          Process.killPid(
            int.parse(checkpoint.readAsStringSync()),
            ProcessSignal.sigkill,
          ),
          isTrue,
        );
        expect(await child.exitCode, isNot(0));
      } finally {
        child.kill();
        await output;
        await errors;
      }
      for (var replay = 0; replay < 2; replay++) {
        final lease = await exclusive();
        final owner = await prepare(lease);
        expect(
          fresh
              ? await owner.initializeFresh()
              : await owner.importLegacy(source),
          isA<Ok>(),
        );
        final store = await open(lease);
        final sequence = await store.database
            .customSelect('SELECT name,seq FROM sqlite_sequence ORDER BY name')
            .get();
        expect(
          sequence.map((row) => row.data.values.toList()).toList(),
          fresh
              ? [
                  ['recoverbull', 1],
                  ['settings', 1],
                ]
              : [
                  ['recoverbull', 120],
                  ['settings', 90],
                ],
        );
        expect(
          (await store.database
                  .customSelect('SELECT id FROM legacy_import_receipts')
                  .get())
              .length,
          1,
        );
        await lease.close();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
