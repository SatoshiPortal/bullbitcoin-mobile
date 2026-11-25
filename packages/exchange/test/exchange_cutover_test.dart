import 'dart:io';

import 'package:exchange/src/data/storage/exchange_credential_import.dart'
    show exchangeCredentialImportForTesting;
import 'package:exchange/exchange.dart';
import 'package:exchange/src/data/storage/exchange_credential_storage.dart';
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exchange-cutover-');
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => directory.path);
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
    await secrets.exchangeKeychain.write(_mainnetRecord, isTestnet: false);
    await secrets.exchangeKeychain.write(_testnetRecord, isTestnet: true);
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
      (await secrets.exchangeKeychain.read(isTestnet: false) as Ok).value,
      _mainnetRecord,
    );
    expect(
      (await secrets.exchangeKeychain.read(isTestnet: true) as Ok).value,
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
          isA<LegacyImportUnavailable>(),
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

  test(
    'a residual keychain record on a fresh install starts signed out',
    () async {
      await source.delete();
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
      expect(
        (await secrets.exchangeKeychain.read(isTestnet: false) as Ok).value,
        _mainnetRecord,
      );
      expect(
        (await secrets.exchangeKeychain.read(isTestnet: true) as Ok).value,
        _testnetRecord,
      );
      // Later launches stay admitted and never read the keychain again.
      final admission2 = admitted(await cutover().prepare());
      await admission2.close();
    },
  );

  test(
    'a marker published before Exchange joined also ignores the residue',
    () async {
      await source.delete();
      final before = StorageCutover(
        directory: Directory('${directory.path}/coordination'),
        legacy: LegacySourceStore(
          source: LegacySource(source, 16),
          create: SqliteDatabase.new,
        ),
        expectedOwners: const {'exchange', 'pilot'},
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
        (await secrets.exchangeKeychain.read(isTestnet: false) as Ok).value,
        _mainnetRecord,
      );
    },
  );

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
        (await secrets.exchangeKeychain.read(isTestnet: false) as Ok).value,
        _mainnetRecord,
      );
    },
  );
}
