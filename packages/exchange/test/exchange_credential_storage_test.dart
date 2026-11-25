import 'dart:io';

import 'package:exchange/exchange.dart';
import 'package:exchange/setup.dart';
import 'package:exchange/src/data/storage/exchange_credential_import.dart'
    show exchangeCredentialImportForTesting;
import 'package:exchange/src/data/storage/exchange_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Secrets secrets;
  late NativeFileGate gate;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exchange-storage-');
    FakeSecureStoragePlatform().install();
    secrets = Secrets(scratchDirectory: () async => directory.path);
    gate = NativeFileGate(File('${directory.path}/lifecycle.lock'));
    file = File('${directory.path}/exchange.sqlite');
  });

  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  Future<RuntimeAdmission> runtime() async =>
      await gate.acquire(exclusive: false, timeout: Duration.zero)
          as RuntimeAdmission;

  /// A fresh, admitted store: no legacy record and a seeded Basic Auth row.
  Future<void> provision() async {
    final lease = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final participant = exchangeCredentialImportForTesting(
        file: file,
        secrets: secrets,
      );
      final owner = switch (await participant.prepare(
        lease,
        OwnerOrigin.fresh,
      )) {
        Ok(:final value) => value,
        Err() => fail('provisioning failed'),
      };
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
    } finally {
      await lease.close();
    }
  }

  Future<ExchangeCredentialStorage> open(RuntimeAdmission admission) async =>
      switch (await ExchangeCredentialStorage.openForTesting(
        file: file,
        admission: admission,
        keys: secrets.databaseKeys(module: 'exchange'),
      )) {
        Ok(:final value) => value,
        Err() => fail('the admitted store must open'),
      };

  test('a missing store fails closed and is never created', () async {
    final admission = await runtime();
    try {
      final opened = await ExchangeCredentialStorage.openForTesting(
        file: file,
        admission: admission,
        keys: secrets.databaseKeys(module: 'exchange'),
      );
      expect(
        opened,
        isA<Err<ExchangeCredentialStorage, ExchangeFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<ExchangeCredentialsUnavailableFailure>(),
        ),
      );
      expect(file.existsSync(), isFalse);
    } finally {
      await admission.close();
    }
  });

  test('a store without a committed receipt is refused', () async {
    final exclusive = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    try {
      final created = await ExchangeStore.openForTesting(
        file: file,
        admission: exclusive,
        keys: secrets.databaseKeys(module: 'exchange'),
        existing: false,
      );
      expect(created, isA<Ok>());
      await (created as Ok<ExchangeStore, LegacyImportFailure>).value.handle
          .close();
    } finally {
      await exclusive.close();
    }
    final admission = await runtime();
    try {
      expect(
        await ExchangeCredentialStorage.openForTesting(
          file: file,
          admission: admission,
          keys: secrets.databaseKeys(module: 'exchange'),
        ),
        isA<Err<ExchangeCredentialStorage, ExchangeFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<ExchangeCredentialsUnavailableFailure>(),
        ),
      );
    } finally {
      await admission.close();
    }
  });

  test('credentials round-trip verbatim and per environment', () async {
    await provision();
    final admission = await runtime();
    try {
      final storage = await open(admission);
      expect(await storage.readApiKeyRecord(isTestnet: false), isNull);
      const record = '{ "key" :"verbatim",  "isActive":true }';
      await storage.writeApiKeyRecord(record, isTestnet: true);
      expect(await storage.readApiKeyRecord(isTestnet: true), record);
      expect(await storage.readApiKeyRecord(isTestnet: false), isNull);
      await storage.writeApiKeyRecord(null, isTestnet: true);
      expect(await storage.readApiKeyRecord(isTestnet: true), isNull);

      await storage.writeBasicAuth(username: 'user', password: 'password');
      expect(await storage.readBasicAuth(), (
        username: 'user',
        password: 'password',
      ));
      await storage.writeBasicAuth(username: 'only-user');
      expect(await storage.readBasicAuth(), (
        username: 'only-user',
        password: null,
      ));
      await storage.close();
    } finally {
      await admission.close();
    }
  });

  test('a write persists across a reopen', () async {
    await provision();
    var admission = await runtime();
    var storage = await open(admission);
    await storage.writeApiKeyRecord('stored', isTestnet: false);
    await storage.close();
    await admission.close();

    admission = await runtime();
    try {
      storage = await open(admission);
      expect(await storage.readApiKeyRecord(isTestnet: false), 'stored');
      await storage.close();
    } finally {
      await admission.close();
    }
  });

  test(
    'close drains the native handle so a migration can take the gate',
    () async {
      await provision();
      final admission = await runtime();
      final storage = await open(admission);
      await storage.readApiKeyRecord(isTestnet: false);
      await storage.close();
      await admission.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
    },
  );

  test('stored credentials drive the session without a keychain', () async {
    await provision();
    final admission = await runtime();
    try {
      final storage = await open(admission);
      final credentials = ExchangeCredentials.open(storage);
      expect(
        await credentials.readActiveApiKey(isTestnet: true),
        isA<Ok<String?, ExchangeFailure>>().having(
          (ok) => ok.value,
          'signed out',
          isNull,
        ),
      );
      await storage.writeApiKeyRecord(
        '{"key":"session-key","isActive":true}',
        isTestnet: true,
      );
      expect(
        await credentials.readActiveApiKey(isTestnet: true),
        isA<Ok<String?, ExchangeFailure>>().having(
          (ok) => ok.value,
          'key',
          'session-key',
        ),
      );
      final basicAuth = ExchangeCredentials.openBasicAuth(storage);
      expect(await basicAuth.save(username: 'u', password: 'p'), isA<Ok>());
      expect(
        await basicAuth.read(),
        isA<Ok<ExchangeBasicAuthValues, ExchangeFailure>>().having(
          (ok) => ok.value,
          'values',
          (username: 'u', password: 'p'),
        ),
      );
      await storage.close();
    } finally {
      await admission.close();
    }
  });
}
