import 'dart:io';

import 'package:exchange/migration.dart';
import 'package:exchange/src/data/storage/exchange_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

T _value<T, F extends Failure>(Result<T, F> result) => switch (result) {
  Ok(:final value) => value,
  Err() => fail('operation failed'),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Secrets secrets;
  late FakeSecureStoragePlatform keystore;
  late NativeFileGate gate;
  late File destination;
  late File source;
  late ExchangeCredentialImport participant;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exchange-import-');
    keystore = FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => directory.path);
    gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
    destination = File('${directory.path}/exchange.sqlite');
    source = File('${directory.path}/legacy.sqlite');
    participant = ExchangeCredentialImport(file: destination, secrets: secrets);
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  Future<ExclusiveAdmission> exclusive() async =>
      await gate.acquire(exclusive: true, timeout: Duration.zero)
          as ExclusiveAdmission;

  test('fresh provenance refuses a retained empty record and an unreadable keychain', () async {
    final lease = await exclusive();
    try {
      expect(
        await participant.verifyInitialSource(
          lease,
          legacySqlitePresent: false,
        ),
        isA<Ok<void, LegacyImportFailure>>(),
      );
      _value(await secrets.exchangeKeychain.write('', isTestnet: true));
      expect(
        await participant.verifyInitialSource(
          lease,
          legacySqlitePresent: false,
        ),
        isA<Err<void, LegacyImportFailure>>().having(
          (outcome) => outcome.failure,
          'failure',
          isA<LegacyImportVerificationFailed>(),
        ),
      );
      expect(
        await participant.prepare(lease, OwnerOrigin.fresh),
        isA<Err<PreparedOwner, LegacyImportFailure>>(),
      );
      keystore.locked = true;
      expect(
        await participant.verifyInitialSource(
          lease,
          legacySqlitePresent: false,
        ),
        isA<Err<void, LegacyImportFailure>>().having(
          (outcome) => outcome.failure,
          'failure',
          isA<LegacyImportDeferred>(),
        ),
      );
      expect(await participant.hasState(), isFalse);
      expect(await source.exists(), isFalse);
    } finally {
      await lease.close();
    }
  });

  test(
    'imports exact rows and does not reimport after a committed receipt',
    () async {
      final opaqueRecord = String.fromCharCode(123);
      _value(
        await secrets.exchangeKeychain.write(opaqueRecord, isTestnet: false),
      );
      _value(await secrets.exchangeKeychain.write('', isTestnet: true));
      final legacy = sqlite3.open(source.path);
      try {
        legacy.userVersion = 16;
        legacy.execute('''
        CREATE TABLE settings (
          id INTEGER PRIMARY KEY,
          exchange_testnet_basic_auth_username TEXT,
          exchange_testnet_basic_auth_password TEXT
        );
        INSERT INTO settings VALUES (2, NULL, ''), (7, '', NULL);
      ''');
      } finally {
        legacy.close();
      }

      final initialSourceBytes = await source.readAsBytes();
      final lease = await exclusive();
      try {
        final owner = _value(
          await participant.prepare(lease, OwnerOrigin.legacy),
        );
        _value(await owner.importLegacy(LegacySource(source, 16)));
        expect(_value(await owner.receipt()), OwnerReadiness.imported);
        _value(await owner.close());

        final reopened = _value(
          await participant.prepare(lease, OwnerOrigin.legacy),
        );
        final readsBefore = keystore.reads;
        _value(await reopened.importLegacy(LegacySource(source, 16)));
        expect(keystore.reads, readsBefore);
        _value(await reopened.close());
      } finally {
        await lease.close();
      }

      final runtime = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      try {
        expect(
          _value(await participant.inspect(runtime)),
          OwnerReadiness.imported,
        );
        final store = _value(
          await ExchangeStore.open(
            file: destination,
            admission: runtime,
            keys: secrets.databaseKeys(module: 'exchange'),
            existing: true,
          ),
        );
        final api = await store.database
            .customSelect(
              'SELECT encoded_record FROM exchange_api_credentials ORDER BY environment',
            )
            .get();
        expect(api.length, 2);
        expect(api[0].data['encoded_record'] == opaqueRecord, isTrue);
        expect(api[1].data['encoded_record'] == '', isTrue);
        final settings = await store.database
            .customSelect(
              'SELECT settings_id, username, password FROM exchange_basic_auth ORDER BY settings_id',
            )
            .get();
        expect(settings.map((row) => row.read<int>('settings_id')), [2, 7]);
        expect(settings.first.data['username'] == null, isTrue);
        expect(settings.first.data['password'] == '', isTrue);
        expect(settings.last.data['username'] == '', isTrue);
        expect(settings.last.data['password'] == null, isTrue);
      } finally {
        await runtime.close();
      }
      expect(await source.readAsBytes(), initialSourceBytes);
      expect(
        _value(await secrets.exchangeKeychain.read(isTestnet: false)) ==
            opaqueRecord,
        isTrue,
      );
      expect(
        _value(await secrets.exchangeKeychain.read(isTestnet: true)) == '',
        isTrue,
      );
    },
  );

  test(
    'incomplete historical schema does not leave a receipt or rows',
    () async {
      final legacy = sqlite3.open(source.path);
      try {
        legacy.userVersion = 16;
        legacy.execute('CREATE TABLE settings (id INTEGER PRIMARY KEY)');
      } finally {
        legacy.close();
      }
      final lease = await exclusive();
      try {
        final owner = _value(
          await participant.prepare(lease, OwnerOrigin.legacy),
        );
        expect(
          await owner.importLegacy(LegacySource(source, 16)),
          isA<Err<void, LegacyImportFailure>>(),
        );
        expect(_value(await owner.receipt()), OwnerReadiness.pending);
        _value(await owner.close());
        final store = _value(
          await ExchangeStore.open(
            file: destination,
            admission: lease,
            keys: secrets.databaseKeys(module: 'exchange'),
            existing: true,
          ),
        );
        expect(
          await store.database
              .customSelect('SELECT 1 FROM exchange_api_credentials LIMIT 1')
              .get(),
          isEmpty,
        );
        expect(
          await store.database
              .customSelect('SELECT 1 FROM exchange_basic_auth LIMIT 1')
              .get(),
          isEmpty,
        );
      } finally {
        await lease.close();
      }
    },
  );
}
