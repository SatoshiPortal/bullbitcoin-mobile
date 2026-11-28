import 'dart:io';

import 'package:bull_payjoin/bull_payjoin.dart' show PayjoinLabelsPort;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:labels/labels.dart';
import 'package:labels/setup.dart';
import 'package:labels/testing.dart' show createLabelsForTesting;
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:labels/src/data/labels_import.dart';
import 'package:labels/src/data/labels_store.dart';
import 'package:labels/src/data/frozen_utxos_freeze_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sync/sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DatabaseKeys keys;
  late NativeFileGate gate;
  late ExclusiveAdmission admission;
  late PreparedOwner owner;
  Future<void> Function(String)? checkpoint;

  File destination() => File('${directory.path}/labels.sqlite');
  LegacySource source() =>
      LegacySource(File('${directory.path}/legacy.sqlite'), 16);
  LabelsImport participant() => createLabelsImportForTesting(
    file: destination(),
    keys: keys,
    checkpoint: (point) async => checkpoint?.call(point),
  );

  setUp(() async {
    checkpoint = null;
    directory = await Directory.systemTemp.createTemp('labels-import-');
    FakeSecureStoragePlatform().install();
    keys = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    ).databaseKeys(module: 'labels');
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

  void legacy({
    bool empty = false,
    Object? sequence = 99,
    bool duplicateSequence = false,
  }) {
    final db = sqlite3.open(source().file.path);
    db.execute(
      'CREATE TABLE labels(id INTEGER PRIMARY KEY AUTOINCREMENT,label TEXT NOT NULL,reference TEXT NOT NULL,type TEXT NOT NULL,origin TEXT,UNIQUE(label,reference))',
    );
    db.execute(
      'CREATE TABLE frozen_utxos(wallet_id TEXT NOT NULL,tx_id TEXT NOT NULL,vout INTEGER NOT NULL,PRIMARY KEY(wallet_id,tx_id,vout))',
    );
    if (!empty) {
      db.execute(
        "INSERT INTO labels VALUES (4,'exact label','same-reference','unknown-future-type',NULL),(7,'other label','same-reference','tx','')",
      );
      db.execute(
        "INSERT INTO frozen_utxos VALUES ('orphan-wallet','frozen-tx',2),('other-origin','frozen-tx',2)",
      );
    }
    db.execute("DELETE FROM sqlite_sequence WHERE name='labels'");
    if (sequence != null) {
      db.execute("INSERT INTO sqlite_sequence VALUES ('labels',?)", [sequence]);
      if (duplicateSequence) {
        db.execute("INSERT INTO sqlite_sequence VALUES ('labels',?)", [
          sequence,
        ]);
      }
    }
    db.userVersion = 16;
    db.close();
  }

  Future<LabelsStore> store() async {
    final opened = await LabelsStore.open(
      destination(),
      admission,
      existing: true,
      testingKeys: keys,
    );
    return (opened as Ok<LabelsStore, DatabaseOpenFailure>).value;
  }

  test('copies raw labels and global freezes with origins and deleted high-water', () async {
    legacy();
    expect(await owner.importLegacy(source()), isA<Ok>());
    final current = await store();
    final old = sqlite3.open(source().file.path, mode: OpenMode.readOnly);
    try {
      for (final table in ['labels', 'frozen_utxos']) {
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
      expect(await readLabelsSequence(current.database), 99);
      final labels = createLabelsForTesting(
        database: current.database,
        listAttributedFreezes: () => fail('Unexpected freeze read'),
        freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
        openWallet: (_) async => throw StateError('Wallet must remain lazy'),
      );
      final freezes = labels.freezes;
      final frozen = await freezes.readAll();
      expect(
        frozen,
        isA<Ok<List<FrozenOutpoint>, SyncFailure>>().having(
          (r) => r.value.map((row) => row.origin).toSet(),
          'both origins',
          {'orphan-wallet', 'other-origin'},
        ),
      );
      expect(await freezes.unfreeze([(txId: 'frozen-tx', vout: 2)]), isA<Ok>());
      expect(
        (await freezes.readAll() as Ok<List<FrozenOutpoint>, SyncFailure>)
            .value,
        isEmpty,
      );
      await current.database.customStatement(
        "INSERT INTO labels(label,reference,type) VALUES ('next','next','tx')",
      );
      expect(
        (await current.database
                .customSelect("SELECT id FROM labels WHERE reference='next'")
                .getSingle())
            .read<int>('id'),
        100,
      );
    } finally {
      old.close();
      await current.handle.close();
    }
  });

  for (final sequence in <int?>[null, 0, 99, 9223372036854775807]) {
    test(
      'empty source preserves sequence $sequence without normalization',
      () async {
        legacy(empty: true, sequence: sequence);
        expect(await owner.importLegacy(source()), isA<Ok>());
        final current = await store();
        expect(await readLabelsSequence(current.database), sequence);
        expect(
          await current.database.customSelect('SELECT * FROM labels').get(),
          isEmpty,
        );
        if (sequence == 9223372036854775807) {
          await expectLater(
            current.database.customStatement(
              "INSERT INTO labels(label,reference,type) VALUES ('overflow','overflow','tx')",
            ),
            throwsA(isA<SqliteException>()),
          );
          expect(await readLabelsSequence(current.database), sequence);
        }
        await current.handle.close();
      },
    );
  }

  for (final sequence in <Object?>[null, -1, 6, 1.5, '99']) {
    test(
      'invalid nonempty source sequence $sequence rejects without receipt',
      () async {
        legacy(sequence: sequence);
        expect(await owner.importLegacy(source()), isA<Err>());
        final current = await store();
        expect(
          await current.database.customSelect('SELECT * FROM labels').get(),
          isEmpty,
        );
        expect(
          await current.database
              .customSelect('SELECT * FROM legacy_import_receipts')
              .get(),
          isEmpty,
        );
        expect(await readLabelsSequence(current.database), isNull);
        await current.handle.close();
      },
    );
  }

  test('duplicate source sequence is a conflict', () async {
    legacy(duplicateSequence: true);
    expect(await owner.importLegacy(source()), isA<Err>());
  });

  for (final fresh in [false, true]) {
    test(
      'empty used destination conflicts for ${fresh ? 'fresh' : 'import'}',
      () async {
        legacy();
        final current = await store();
        await current.database.customStatement(
          "INSERT INTO sqlite_sequence VALUES ('labels',123)",
        );
        expect(
          fresh
              ? await owner.initializeFresh()
              : await owner.importLegacy(source()),
          isA<Err>(),
        );
        expect(await readLabelsSequence(current.database), 123);
        expect(
          await current.database
              .customSelect('SELECT * FROM legacy_import_receipts')
              .get(),
          isEmpty,
        );
        await current.handle.close();
      },
    );
  }

  for (final sequence in <int?>[null, 0]) {
    test('fresh proof preserves unused sequence $sequence', () async {
      final current = await store();
      if (sequence != null) {
        await current.database.customStatement(
          "INSERT INTO sqlite_sequence VALUES ('labels',0)",
        );
      }
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await readLabelsSequence(current.database), sequence);
      expect(
        (await current.database
                .customSelect('SELECT id FROM legacy_import_receipts')
                .getSingle())
            .read<String>('id'),
        labelsFreshReceipt,
      );
      await current.handle.close();
    });
  }

  test(
    'failure after sequence restoration rolls back rows sequence and receipt',
    () async {
      legacy();
      checkpoint = (point) async {
        if (point == 'import-sequence') {
          throw const FileSystemException('injected checkpoint');
        }
      };
      expect(await owner.importLegacy(source()), isA<Err>());
      final current = await store();
      for (final table in [
        'labels',
        'frozen_utxos',
        'legacy_import_receipts',
      ]) {
        expect(
          await current.database.customSelect('SELECT * FROM $table').get(),
          isEmpty,
        );
      }
      expect(await readLabelsSequence(current.database), isNull);
      checkpoint = null;
      expect(await owner.importLegacy(source()), isA<Ok>());
      expect(await readLabelsSequence(current.database), 99);
      await current.handle.close();
    },
  );

  test('valid receipt plus unknown receipt never permits replay', () async {
    legacy();
    expect(await owner.importLegacy(source()), isA<Ok>());
    final current = await store();
    await current.database.customStatement(
      "INSERT INTO legacy_import_receipts VALUES ('unknown')",
    );
    expect(await owner.receipt(), isA<Err>());
    expect(await owner.importLegacy(source()), isA<Err>());
    await current.handle.close();
  });

  test('owner replay preserves live freeze changes without source', () async {
    legacy();
    expect(await owner.importLegacy(source()), isA<Ok>());
    final current = await store();
    await current.database.customStatement(
      "INSERT INTO frozen_utxos VALUES ('live','live-tx',3)",
    );
    await source().file.delete();
    expect(await owner.importLegacy(source()), isA<Ok>());
    expect(
      await current.database.customSelect('SELECT * FROM frozen_utxos').get(),
      hasLength(3),
    );
    await current.handle.close();
  });

  test(
    'Payjoin, reservations and the freeze port share the owner store',
    () async {
      expect(await owner.initializeFresh(), isA<Ok>());
      final current = await store();
      final services = GetIt.asNewInstance();
      addTearDown(services.reset);
      final labels = createLabelsForTesting(
        database: current.database,
        listAttributedFreezes: () => fail('Unexpected freeze read'),
        freezeAttributedOutpoints: (_) => fail('Unexpected freeze'),
        openWallet: (_) async => throw StateError('Wallet must remain lazy'),
      );
      setupLabels(services, labels);
      final key = WalletKey(
        id: 'different-wallet',
        network: BitcoinNetwork.mainnet,
      );
      expect(
        await labels.store(
          NewLabel.addr(
            address: 'global-reference',
            label: LabelSystem.payjoin.label,
            origin: 'origin',
          ),
        ),
        isA<Ok>(),
      );
      expect(
        await services<ReservedAddressPort>().isReserved(
          key,
          'global-reference',
        ),
        isA<Ok<bool, SyncFailure>>().having(
          (result) => result.value,
          'reserved',
          isTrue,
        ),
      );
      final txid = 'a' * 64;
      await services<PayjoinLabelsPort>().labelTransaction(
        walletId: 'origin',
        transactionId: txid,
      );
      final fetched = await labels.fetch(reference: txid);
      expect(
        (fetched as Ok<List<Label>, LabelFailure>).value.single.origin,
        'origin',
      );
      expect(services<FreezeStorePort>(), same(labels.freezes));
      await current.handle.close();
    },
  );

  test(
    'unavailable freeze storage returns error instead of empty set',
    () async {
      legacy();
      expect(await owner.importLegacy(source()), isA<Ok>());
      final current = await store();
      final freezes = FrozenUtxosFreezeStore(database: current.database);
      await current.database.customStatement('DROP TABLE frozen_utxos');
      expect(
        await freezes.readAll(),
        isA<Err<List<FrozenOutpoint>, SyncFailure>>(),
      );
      await current.handle.close();
    },
  );

  test('wrong key and sidecar-only state cannot reopen the owner', () async {
    expect(await owner.initializeFresh(), isA<Ok>());
    expect(await owner.close(), isA<Ok>());
    await admission.close();
    final before = await destination().readAsBytes();
    FakeSecureStoragePlatform().install();
    expect(await keys.getOrCreate(name: 'main'), isA<Ok>());
    final shared = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    addTearDown(shared.close);
    expect(await participant().inspect(shared), isA<Err>());
    expect(await destination().readAsBytes(), before);

    await destination().rename('${destination().path}.retained');
    final sidecar = await File('${destination().path}-wal').create();
    expect(await participant().inspect(shared), isA<Err>());
    expect(sidecar.existsSync(), isTrue);
    expect(destination().existsSync(), isFalse);
    await shared.close();
  });

  test('failure before fresh commit does not claim readiness', () async {
    checkpoint = (step) async {
      if (step == 'fresh-receipt') {
        throw const FileSystemException('injected checkpoint');
      }
    };
    expect(await owner.initializeFresh(), isA<Err>());
    expect(
      await owner.receipt(),
      isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
        (r) => r.value,
        'readiness',
        OwnerReadiness.pending,
      ),
    );
    checkpoint = null;
    expect(await owner.initializeFresh(), isA<Ok>());
  });
}
