import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:electrum/src/data/electrum_import.dart';
import 'package:electrum/src/data/electrum_store.dart';
import 'package:electrum/src/domain/electrum_default_endpoints.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late FakeSecureStoragePlatform keystore;
  late DatabaseKeys keys;
  late NativeFileGate gate;
  late ExclusiveAdmission admission;
  late PreparedOwner owner;
  Future<void> Function(String)? checkpoint;

  File destination() => File('${directory.path}/electrum.sqlite');
  LegacySource source() =>
      LegacySource(File('${directory.path}/legacy.sqlite'), 16);
  ElectrumImport participant() => createElectrumImportForTesting(
    file: destination(),
    keys: keys,
    checkpoint: (step) async => checkpoint?.call(step),
  );

  setUp(() async {
    checkpoint = null;
    directory = await Directory.systemTemp.createTemp('electrum-import-');
    keystore = FakeSecureStoragePlatform()..install();
    keys = Secrets(scratchDirectory: () async => directory.path)
        .databaseKeys(module: 'electrum');
    gate = NativeFileGate(File('${directory.path}/gate'));
    admission = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    final prepared = await participant().prepare(admission, OwnerOrigin.legacy);
    expect(prepared, isA<Ok>());
    owner = (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
    expect(
      await owner.receipt(),
      isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
        (r) => r.value,
        'pending schema',
        OwnerReadiness.pending,
      ),
    );
  });
  tearDown(() async {
    expect(await owner.close(), isA<Ok>());
    await admission.close();
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  void legacy({bool empty = false}) {
    final db = sqlite3.open(source().file.path);
    db.execute(
      'CREATE TABLE electrum_servers(url TEXT NOT NULL,network TEXT NOT NULL,priority INTEGER NOT NULL,is_custom INTEGER NOT NULL CHECK(is_custom IN(0,1)),PRIMARY KEY(network,url))',
    );
    db.execute(
      'CREATE TABLE electrum_settings(network TEXT PRIMARY KEY NOT NULL,validate_domain INTEGER NOT NULL,stop_gap INTEGER NOT NULL,timeout INTEGER NOT NULL,retry INTEGER NOT NULL,socks5 TEXT)',
    );
    db.execute(
      'CREATE TABLE transactions(txid TEXT PRIMARY KEY NOT NULL,version INTEGER NOT NULL,size TEXT NOT NULL,vsize TEXT NOT NULL,locktime INTEGER NOT NULL,vin TEXT NOT NULL,vout TEXT NOT NULL,blockhash TEXT,height INTEGER,confirmations INTEGER,time INTEGER,blocktime INTEGER)',
    );
    if (!empty) {
      db.execute(
        "INSERT INTO electrum_servers VALUES ('SSL://EXACT.example:50002','unknown-network',-3,1),('tcp://default.example:50001','bitcoinMainnet',7,0)",
      );
      db.execute(
        "INSERT INTO electrum_settings VALUES ('unknown-network',0,17,19,23,NULL),('bitcoinMainnet',1,20,5,5,'')",
      );
      db.execute(
        "INSERT INTO transactions VALUES ('exact-cache',2,'00042','00021',123,' [ 1 ] ',' [] ',NULL,NULL,0,NULL,99)",
      );
    }
    db.userVersion = 16;
    db.close();
  }

  Future<ElectrumStore> store() async {
    final opened = await ElectrumStore.open(
      destination(),
      admission,
      existing: true,
      testingKeys: keys,
    );
    return (opened as Ok<ElectrumStore, DatabaseOpenFailure>).value;
  }

  test(
    'copies all raw fields including unknown network and cache nulls',
    () async {
      legacy();
      expect(await owner.importLegacy(source()), isA<Ok>());
      final current = await store();
      final old = sqlite3.open(source().file.path, mode: OpenMode.readOnly);
      try {
        for (final table in [
          'electrum_servers',
          'electrum_settings',
          'transactions',
        ]) {
          final actual = await current.database
              .customSelect('SELECT * FROM $table ORDER BY 1')
              .get();
          expect(
            actual.map((row) => row.data.values.toList()).toList(),
            old
                .select('SELECT * FROM $table ORDER BY 1')
                .map((row) => row.values.toList())
                .toList(),
          );
        }
        expect(
          await owner.receipt(),
          isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
            (r) => r.value,
            'readiness',
            OwnerReadiness.imported,
          ),
        );
      } finally {
        old.close();
        await current.handle.close();
      }
    },
  );

  test(
    'empty upgrade stays empty and does not receive fresh defaults',
    () async {
      legacy(empty: true);
      expect(await owner.importLegacy(source()), isA<Ok>());
      final current = await store();
      for (final table in [
        'electrum_servers',
        'electrum_settings',
        'transactions',
      ]) {
        expect(
          await current.database.customSelect('SELECT * FROM $table').get(),
          isEmpty,
        );
      }
      await current.handle.close();
    },
  );

  test('fresh seeds and sole receipt are durable and idempotent', () async {
    expect(await owner.initializeFresh(), isA<Ok>());
    expect(await owner.initializeFresh(), isA<Ok>());
    final current = await store();
    final servers = await current.database
        .customSelect('SELECT * FROM electrum_servers')
        .get();
    expect(
      servers.map((row) => row.data.values.toList()),
      unorderedEquals([
        [ElectrumDefaultEndpoints.fulcrumElectrumUrl, 'bitcoinMainnet', 0, 0],
        [ElectrumDefaultEndpoints.bbElectrumUrl, 'bitcoinMainnet', 1, 0],
        [ElectrumDefaultEndpoints.publicElectrumUrl, 'bitcoinMainnet', 2, 0],
        [
          ElectrumDefaultEndpoints.bbLiquidElectrumUrlPath,
          'liquidMainnet',
          0,
          0,
        ],
        [
          ElectrumDefaultEndpoints.publicLiquidElectrumUrlPath,
          'liquidMainnet',
          1,
          0,
        ],
        [
          ElectrumDefaultEndpoints.publicElectrumTestUrl,
          'bitcoinTestnet',
          0,
          0,
        ],
        [
          ElectrumDefaultEndpoints.publicliquidElectrumTestUrlPath,
          'liquidTestnet',
          0,
          0,
        ],
        ['tcp://127.0.0.1:50000', 'bitcoinRegtest', 0, 0],
      ]),
    );
    final settings = await current.database
        .customSelect('SELECT * FROM electrum_settings')
        .get();
    expect(
      settings.map((row) => row.data.values.toList()),
      unorderedEquals([
        ['bitcoinMainnet', 1, 20, 5, 5, null],
        ['liquidMainnet', 1, 20, 5, 5, null],
        ['bitcoinTestnet', 1, 20, 5, 5, null],
        ['liquidTestnet', 1, 20, 5, 5, null],
        ['bitcoinRegtest', 1, 20, 5, 5, null],
      ]),
    );
    expect(
      await current.database.customSelect('SELECT * FROM transactions').get(),
      isEmpty,
    );
    expect(
      (await current.database
              .customSelect('SELECT id FROM legacy_import_receipts')
              .getSingle())
          .read<String>('id'),
      electrumFreshReceipt,
    );
    await current.handle.close();
    expect(await owner.importLegacy(source()), isA<Err>());
  });

  for (final receipt in ['unknown', electrumFreshReceipt]) {
    test(
      'rejects additional receipt $receipt even alongside import receipt',
      () async {
        legacy();
        expect(await owner.importLegacy(source()), isA<Ok>());
        final current = await store();
        await current.database.customStatement(
          'INSERT INTO legacy_import_receipts VALUES (?)',
          [receipt],
        );
        await current.handle.close();
        expect(await owner.receipt(), isA<Err>());
        expect(await owner.importLegacy(source()), isA<Err>());
      },
    );
  }

  test('owner replay needs no source and preserves changed cache', () async {
    legacy();
    expect(await owner.importLegacy(source()), isA<Ok>());
    final current = await store();
    await current.database.customStatement(
      "UPDATE transactions SET size = 'new-live-value'",
    );
    await source().file.delete();
    expect(await owner.importLegacy(source()), isA<Ok>());
    expect(
      (await current.database
              .customSelect('SELECT size FROM transactions')
              .getSingle())
          .read<String>('size'),
      'new-live-value',
    );
    await current.handle.close();
  });

  test(
    'unreceipted destination content conflicts without overwriting',
    () async {
      legacy();
      final current = await store();
      await current.database.customStatement(
        "INSERT INTO electrum_servers VALUES ('preexisting','bitcoinMainnet',0,1)",
      );
      expect(await owner.importLegacy(source()), isA<Err>());
      expect(
        await current.database
            .customSelect('SELECT * FROM legacy_import_receipts')
            .get(),
        isEmpty,
      );
      expect(
        (await current.database
                .customSelect('SELECT url FROM electrum_servers')
                .getSingle())
            .read<String>('url'),
        'preexisting',
      );
      await current.handle.close();
    },
  );

  test('copy failure rolls back earlier tables and receipt', () async {
    legacy();
    final old = sqlite3.open(source().file.path);
    old.execute('DROP TABLE transactions');
    old.close();
    expect(await owner.importLegacy(source()), isA<Err>());
    final current = await store();
    for (final table in [
      'electrum_servers',
      'electrum_settings',
      'legacy_import_receipts',
    ]) {
      expect(
        await current.database.customSelect('SELECT * FROM $table').get(),
        isEmpty,
      );
    }
    await current.handle.close();
  });

  test('missing key cannot reopen or replace an existing owner', () async {
    expect(await owner.initializeFresh(), isA<Ok>());
    expect(await owner.close(), isA<Ok>());
    await admission.close();
    final before = await destination().readAsBytes();
    keystore.entries.clear();
    final shared = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    expect(await participant().inspect(shared), isA<Err>());
    await shared.close();
    expect(await destination().readAsBytes(), before);
    expect(keystore.entries, isEmpty);
  });

  test('failure before fresh commit rolls back seeds and receipt', () async {
    checkpoint = (step) async {
      if (step == 'fresh-receipt') {
        throw const FileSystemException('injected checkpoint');
      }
    };
    expect(await owner.initializeFresh(), isA<Err>());
    final current = await store();
    for (final table in [
      'electrum_servers',
      'electrum_settings',
      'transactions',
      'legacy_import_receipts',
    ]) {
      expect(
        await current.database.customSelect('SELECT * FROM $table').get(),
        isEmpty,
      );
    }
    await current.handle.close();
    checkpoint = null;
    expect(await owner.initializeFresh(), isA<Ok>());
  });
}
