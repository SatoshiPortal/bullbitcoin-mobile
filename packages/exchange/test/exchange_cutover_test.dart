import 'dart:convert';
import 'dart:io';

import 'package:exchange/src/data/storage/exchange_credential_import.dart'
    show exchangeCredentialImportForTesting;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/storage/exchange_credential_storage.dart';
import 'package:exchange/src/data/storage/exchange_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

const _mainnetRecord = '{"key":"legacy-mainnet","isActive":true}';
const _testnetRecord = '{"key":"legacy-testnet","isActive":true}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Secrets secrets;
  late File destination;
  late File source;
  late _RecordingKeystore keystore;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exchange-cutover-');
    keystore = _RecordingKeystore();
    keystore.install();
    secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    );
    destination = File('${directory.path}/exchange.sqlite');
    source = File('${directory.path}/legacy.sqlite');
    final legacy = sqlite3.open(source.path);
    try {
      legacy.userVersion = 16;
      legacy.execute('''
        CREATE TABLE settings (
          id INTEGER PRIMARY KEY,
          exchange_testnet_basic_auth_username TEXT,
          exchange_testnet_basic_auth_password TEXT
        );
        INSERT INTO settings VALUES (1, 'legacy-user', 'legacy-password');
      ''');
    } finally {
      legacy.close();
    }
    await LegacyExchangeKeychainFixture().write(
      _mainnetRecord,
      isTestnet: false,
    );
    await LegacyExchangeKeychainFixture().write(
      _testnetRecord,
      isTestnet: true,
    );
    keystore.exchangeOps.clear();
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  StorageCutover cutover({Future<void> Function(String)? durableStep}) =>
      StorageCutover(
        directory: Directory('${directory.path}/coordination'),
        legacy: LegacySourceStore(
          source: LegacySource(source, 16),
          create: SqliteDatabase.new,
        ),
        expectedOwners: const {'exchange'},
        participants: [
          exchangeCredentialImportForTesting(
            file: destination,
            secrets: secrets,
          ),
        ],
        durableStep: durableStep,
      );

  RuntimeAdmission admitted(Result<RuntimeAdmission, LegacyImportFailure> r) =>
      switch (r) {
        Ok(:final value) => value,
        Err(:final failure) => fail('admission failed: ${failure.runtimeType}'),
      };

  Future<Result<ExchangeCredentialStorage, ExchangeFailure>> open(
    RuntimeAdmission admission,
  ) => ExchangeCredentialStorage.openForTesting(
    file: destination,
    admission: admission,
    keys: secrets.databaseKeys(module: 'exchange'),
  );

  Future<void> expectUpgraded(RuntimeAdmission admission) async {
    final opened = await open(admission);
    final storage = switch (opened) {
      Ok(:final value) => value,
      Err() => fail('the admitted store must open'),
    };
    // Records are kept verbatim: the store never reinterprets them.
    expect(await storage.readApiKeyRecord(isTestnet: false), _mainnetRecord);
    expect(await storage.readApiKeyRecord(isTestnet: true), _testnetRecord);
    final basicAuth = await storage.readBasicAuth();
    expect(basicAuth.username, 'legacy-user');
    expect(basicAuth.password, 'legacy-password');
    await storage.close();
  }

  Future<void> expectLegacySourcesUntouched() async {
    expect(
      (await LegacyExchangeKeychainFixture().read(
        isTestnet: false,
      ) as Ok).value,
      _mainnetRecord,
    );
    expect(
      (await LegacyExchangeKeychainFixture().read(isTestnet: true) as Ok).value,
      _testnetRecord,
    );
    final legacy = sqlite3.open(source.path, mode: OpenMode.readOnly);
    try {
      expect(
        legacy
            .select(
              'SELECT exchange_testnet_basic_auth_username, '
              'exchange_testnet_basic_auth_password FROM settings',
            )
            .single
            .values,
        ['legacy-user', 'legacy-password'],
      );
    } finally {
      legacy.close();
    }
  }

  test('an upgraded install reaches the Exchange store without losing a '
      'legacy source', () async {
    final admission = admitted(await cutover().prepare());
    try {
      await expectUpgraded(admission);
    } finally {
      await admission.close();
    }
    await expectLegacySourcesUntouched();
  });

  test('a repeated launch over a current store changes nothing', () async {
    await admitted(await cutover().prepare()).close();
    final first = await destination.readAsBytes();
    for (var launch = 0; launch < 2; launch++) {
      final admission = admitted(await cutover().prepare());
      try {
        await expectUpgraded(admission);
      } finally {
        await admission.close();
      }
    }
    expect(await destination.exists(), isTrue);
    expect(first, isNotEmpty);
    await expectLegacySourcesUntouched();
  });

  for (final (name, statement) in [
    ('missing row', 'DELETE FROM exchange_basic_auth WHERE settings_id = 1'),
    (
      'unreadable username',
      "UPDATE exchange_basic_auth SET username = x'ff' WHERE settings_id = 1",
    ),
    (
      'unreadable password',
      "UPDATE exchange_basic_auth SET password = x'ff' WHERE settings_id = 1",
    ),
  ]) {
    test('an admitted store with $name is refused without repair', () async {
      final admission = admitted(await cutover().prepare());
      final opened = await ExchangeStore.openForTesting(
        file: destination,
        admission: admission,
        keys: secrets.databaseKeys(module: 'exchange'),
        existing: true,
      );
      final store = switch (opened) {
        Ok(:final value) => value,
        Err() => fail('the admitted store must open'),
      };
      await store.database.customStatement(statement);
      await store.handle.close();
      expect(
        await open(admission),
        isA<Err<ExchangeCredentialStorage, ExchangeFailure>>(),
      );
      await admission.close();
      expect(
        await cutover().admit(),
        isA<Err<RuntimeAdmission, LegacyImportFailure>>(),
      );
      expect(
        await cutover().prepare(),
        isA<Err<RuntimeAdmission, LegacyImportFailure>>(),
      );
      final lease = await NativeFileGate(
        File('${directory.path}/coordination/lifecycle.lock'),
      ).acquire(exclusive: false, timeout: Duration.zero) as RuntimeAdmission;
      try {
        final raw = switch (await ExchangeStore.openForTesting(
          file: destination,
          admission: lease,
          keys: secrets.databaseKeys(module: 'exchange'),
          existing: true,
        )) {
          Ok(:final value) => value,
          Err() => fail('the store must remain available for inspection'),
        };
        final rows = await raw.database
            .customSelect(
              'SELECT typeof(username) AS username_type, typeof(password) AS password_type '
              'FROM exchange_basic_auth WHERE settings_id = 1',
            )
            .get();
        if (name == 'missing row') {
          expect(rows, isEmpty);
        } else {
          expect(
            rows.single.data[name == 'unreadable username'
                ? 'username_type'
                : 'password_type'],
            'blob',
          );
        }
        await raw.handle.close();
      } finally {
        await lease.close();
      }
      await expectLegacySourcesUntouched();
    });
  }

  group('a crash after each durable step', () {
    for (final step in [
      'marker',
      'source-prepared',
      'marker-established-flushed',
      'marker-established-renamed',
      'source-established',
      // The receipt is committed here, before the marker admits the owner.
      'owner-exchange',
      'marker-owner-exchange-flushed',
      'marker-owner-exchange-renamed',
    ]) {
      test('$step resumes without recopying or losing data', () async {
        final crashed = cutover(
          durableStep: (name) async {
            if (name == step) throw StateError('crash at $name');
          },
        );
        await expectLater(crashed.prepare(), throwsStateError);
        await LifecycleAdmission.retryQuarantined();
        for (var launch = 0; launch < 2; launch++) {
          final admission = admitted(await cutover().prepare());
          try {
            await expectUpgraded(admission);
          } finally {
            await admission.close();
          }
        }
        await expectLegacySourcesUntouched();
      });
    }
  });

  test('a committed receipt is never recopied when the source changes before '
      'admission', () async {
    final crashed = cutover(
      durableStep: (name) async {
        if (name == 'owner-exchange') throw StateError('crash at $name');
      },
    );
    await expectLater(crashed.prepare(), throwsStateError);
    await LifecycleAdmission.retryQuarantined();
    final legacy = sqlite3.open(source.path);
    try {
      legacy.execute(
        "UPDATE settings SET exchange_testnet_basic_auth_username = 'changed', "
        "exchange_testnet_basic_auth_password = 'changed' WHERE id = 1",
      );
      expect(legacy.updatedRows, 1);
    } finally {
      legacy.close();
    }
    for (var launch = 0; launch < 2; launch++) {
      final admission = admitted(await cutover().prepare());
      try {
        await expectUpgraded(admission);
      } finally {
        await admission.close();
      }
    }
  });

  test(
    'a store lost after admission fails closed and is not recreated',
    () async {
      await admitted(await cutover().prepare()).close();
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        final file = File('${destination.path}$suffix');
        if (file.existsSync()) await file.delete();
      }

      final foreground = await cutover().prepare();
      expect(
        foreground,
        isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<LegacyOwnerFailure>().having(
            (failure) => failure.cause,
            'cause',
            LegacyOwnerFailureCause.missingAfterAdmission,
          ),
        ),
      );
      final background = await cutover().admit();
      expect(background, isA<Err<RuntimeAdmission, LegacyImportFailure>>());
      expect(
        destination.existsSync(),
        isFalse,
        reason: 'a recreated empty store would read as a signed-out user',
      );
      await expectLegacySourcesUntouched();
    },
  );

  test('two launches racing for the store import it once', () async {
    final results = await Future.wait([
      cutover().prepare(),
      cutover().prepare(),
    ]);
    for (final result in results) {
      switch (result) {
        case Ok(:final value):
          await value.close();
        case Err(:final failure):
          expect(failure, isA<LegacyImportDeferred>());
      }
    }
    final admission = admitted(await cutover().prepare());
    try {
      await expectUpgraded(admission);
    } finally {
      await admission.close();
    }
    await expectLegacySourcesUntouched();
  });

  test('a residual keychain record on a fresh install starts signed out, '
      'and no launch touches the two Exchange entries', () async {
    await source.delete();
    // Interrupted after the receipt, so the resume runs prepare and the
    // receipt check again over the marker the first launch published.
    final crashed = cutover(
      durableStep: (name) async {
        if (name == 'owner-exchange') throw StateError('crash at $name');
      },
    );
    await expectLater(crashed.prepare(), throwsStateError);
    await LifecycleAdmission.retryQuarantined();
    expect(keystore.exchangeOps, isEmpty, reason: 'first launch');
    for (var launch = 0; launch < 2; launch++) {
      final admission = admitted(await cutover().prepare());
      try {
        final storage = switch (await open(admission)) {
          Ok(:final value) => value,
          Err() => fail('the admitted store must open'),
        };
        expect(await storage.readApiKeyRecord(isTestnet: false), isNull);
        expect(await storage.readApiKeyRecord(isTestnet: true), isNull);
        expect(await storage.readBasicAuth(), (username: null, password: null));
        await storage.close();
      } finally {
        await admission.close();
      }
      expect(keystore.exchangeOps, isEmpty, reason: 'resume $launch');
    }
    expect(
      (await LegacyExchangeKeychainFixture().read(
        isTestnet: false,
      ) as Ok).value,
      _mainnetRecord,
    );
    expect(
      (await LegacyExchangeKeychainFixture().read(isTestnet: true) as Ok).value,
      _testnetRecord,
    );
  });

  for (final version in [1, 2]) {
    test('a v$version marker published before Exchange joined imports the '
        'Basic Auth the app wrote afterwards', () async {
      // No API key: this pins the Settings path only; the key is D103 below.
      keystore.entries.clear();
      await source.delete();
      final markerFile = File('${directory.path}/coordination/split-v1.json');
      final before = StorageCutover(
        directory: Directory('${directory.path}/coordination'),
        legacy: LegacySourceStore(
          source: LegacySource(source, 16),
          create: SqliteDatabase.new,
        ),
        expectedOwners: const {'exchange'},
        participants: const [],
      );
      await admitted(await before.prepare()).close();
      if (version == 1) {
        final data =
            jsonDecode(await markerFile.readAsString()) as Map<String, Object?>;
        data
          ..['version'] = 1
          ..remove('admittedOwners');
        await markerFile.writeAsString(jsonEncode(data));
      }
      final marker =
          jsonDecode(await markerFile.readAsString()) as Map<String, Object?>;
      expect(marker['initialFresh'], isTrue);
      expect(marker['version'], version);
      // The app writes the credentials through Settings after the marker.
      final legacy = sqlite3.open(source.path);
      try {
        legacy.execute(
          'UPDATE settings SET exchange_testnet_basic_auth_username = ?, '
          'exchange_testnet_basic_auth_password = ? WHERE id = 1',
          ['written-user', 'written-password'],
        );
        expect(legacy.updatedRows, 1);
      } finally {
        legacy.close();
      }
      for (var launch = 0; launch < 3; launch++) {
        final admission = admitted(await cutover().prepare());
        try {
          final storage = switch (await open(admission)) {
            Ok(:final value) => value,
            Err() => fail('the admitted store must open'),
          };
          final basicAuth = await storage.readBasicAuth();
          expect(basicAuth.username, 'written-user', reason: 'launch $launch');
          expect(basicAuth.password, 'written-password');
          expect(await storage.readApiKeyRecord(isTestnet: false), isNull);
          expect(await storage.readApiKeyRecord(isTestnet: true), isNull);
          await storage.close();
        } finally {
          await admission.close();
        }
      }
      final published =
          jsonDecode(await markerFile.readAsString()) as Map<String, Object?>;
      expect((published['origins'] as Map)['exchange'], 'legacy');
    });
  }

  // D103: a lone API key under a marker kept from a fresh install is ignored.
  test('a marker published before Exchange joined still ignores the keychain '
      'residue', () async {
    await source.delete();
    final before = StorageCutover(
      directory: Directory('${directory.path}/coordination'),
      legacy: LegacySourceStore(
        source: LegacySource(source, 16),
        create: SqliteDatabase.new,
      ),
      expectedOwners: const {'exchange'},
      participants: const [],
    );
    await admitted(await before.prepare()).close();
    final admission = admitted(await cutover().prepare());
    try {
      final storage = switch (await open(admission)) {
        Ok(:final value) => value,
        Err() => fail('the admitted store must open'),
      };
      expect(await storage.readApiKeyRecord(isTestnet: false), isNull);
      await storage.close();
    } finally {
      await admission.close();
    }
    expect(
      (await LegacyExchangeKeychainFixture().read(
        isTestnet: false,
      ) as Ok).value,
      _mainnetRecord,
    );
  });

  test(
    'a legacy database that disagrees with the store stays blocked',
    () async {
      final legacy = sqlite3.open(source.path);
      legacy.execute('DROP TABLE settings');
      legacy.close();
      final result = await cutover().prepare();
      expect(result, isA<Err<RuntimeAdmission, LegacyImportFailure>>());
      expect(destination.existsSync(), isTrue);
      expect(
        (await LegacyExchangeKeychainFixture().read(
          isTestnet: false,
        ) as Ok).value,
        _mainnetRecord,
      );
    },
  );
}

/// Records every access to the two Exchange entries and nothing else, so a
/// test can require that a launch never reads, writes or deletes them.
class _RecordingKeystore extends FakeSecureStoragePlatform {
  final List<String> exchangeOps = [];

  void _note(String op, String key) {
    if (key.contains('exchange_api_key')) exchangeOps.add('$op $key');
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    _note('read', key);
    return super.read(key: key, options: options);
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) {
    _note('containsKey', key);
    return super.containsKey(key: key, options: options);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) {
    _note('write', key);
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) {
    _note('delete', key);
    return super.delete(key: key, options: options);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) {
    exchangeOps.add('deleteAll');
    return super.deleteAll(options: options);
  }
}
