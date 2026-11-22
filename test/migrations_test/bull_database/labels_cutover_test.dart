import 'dart:io';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electrum/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labels/testing.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mempool/migration.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import 'generated/schema_v15.dart' as v15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final freshPilot in [false, true]) {
    test(
      'Labels imports ${freshPilot ? 'later writes from fresh S1a' : 'published v15'} without replacing source',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'labels-cutover-',
        );
        addTearDown(() async {
          await LifecycleAdmission.retryQuarantined();
          await directory.delete(recursive: true);
        });
        FakeSecureStoragePlatform().install();
        final secrets = Secrets(scratchDirectory: () async => directory.path);
        final source = File('${directory.path}/legacy.sqlite');
        Future<void> writeFixture(GeneratedDatabase database) async {
          await database.customStatement(
            "INSERT INTO labels(id,label,reference,type,origin) VALUES (71,'later','reference','unknown',NULL)",
          );
          await database.customStatement(
            "INSERT INTO frozen_utxos VALUES ('orphan-origin','frozen-tx',3)",
          );
          await database.customStatement(
            "UPDATE sqlite_sequence SET seq=99 WHERE name='labels'",
          );
        }

        if (!freshPilot) {
          final old = v15.DatabaseAtV15(NativeDatabase(source));
          try {
            await writeFixture(old);
          } finally {
            await old.close();
          }
        }
        final legacy = LegacySourceStore(
          source: LegacySource(source, 16),
          create: SqliteDatabase.new,
        );
        final mempool = MempoolImport(
          file: File('${directory.path}/mempool.sqlite'),
          defaultServers: ['a', 'b', 'c', 'd'],
          testingKeys: secrets.databaseKeys(module: 'mempool'),
        );
        final electrumFile = File('${directory.path}/electrum.sqlite');
        final file = File('${directory.path}/labels.sqlite');
        final keys = secrets.databaseKeys(module: 'labels');
        var failLabels = true;
        final participant = createLabelsImportForTesting(
          file: file,
          keys: keys,
          checkpoint: (step) async {
            if (failLabels && step == 'import-rows') {
              throw const FileSystemException('injected label import failure');
            }
          },
        );
        StorageCutover cutover({required bool activate}) => StorageCutover(
          directory: Directory('${directory.path}/coordination'),
          legacy: legacy,
          expectedOwners: splitV1Owners,
          destinationFamilies: [
            file,
            electrumFile,
            File('${directory.path}/mempool.sqlite'),
          ],
          participants: [
            mempool,
            if (activate)
              createElectrumImportForTesting(
                file: electrumFile,
                keys: secrets.databaseKeys(module: 'electrum'),
              ),
            if (activate) participant,
          ],
        );
        // A prior slice establishes legacy provenance even for fresh installs.
        final first = await cutover(activate: false).prepare();
        expect(first, isA<Ok>());
        final admission =
            (first as Ok<RuntimeAdmission, LegacyImportFailure>).value;
        if (freshPilot) await writeFixture(await legacy.open(admission));
        await admission.close();
        expect(await cutover(activate: true).prepare(), isA<Err>());
        // Failed Labels must not publish a mixed runtime or undo Electrum's receipt.
        final exclusive = await NativeFileGate(
          File('${directory.path}/coordination/lifecycle.lock'),
        ).acquire(exclusive: true, timeout: Duration.zero);
        final electrumKeys = secrets.databaseKeys(module: 'electrum');
        final electrumOpen = await electrumKeys.open(
          name: 'main',
          file: electrumFile,
          existingSchemaVersion: 1,
        );
        final electrumProbe = _Probe(
          (electrumOpen as Ok<QueryExecutor, DatabaseOpenFailure>).value,
        );
        exclusive.track(electrumProbe.close);
        expect(
          (await electrumProbe
                  .customSelect('SELECT id FROM legacy_import_receipts')
                  .getSingle())
              .read<String>('id'),
          'split-v1/electrum',
        );
        await electrumProbe.customStatement(
          "INSERT INTO electrum_servers VALUES ('activated-owner-only','unknown-network',99,1)",
        );
        await exclusive.close();
        failLabels = false;
        for (var attempt = 0; attempt < 2; attempt++) {
          final ready = await cutover(activate: true).prepare();
          expect(ready, isA<Ok>());
          final runtime =
              (ready as Ok<RuntimeAdmission, LegacyImportFailure>).value;
          final opened = await keys.open(
            name: 'main',
            file: file,
            existingSchemaVersion: 1,
          );
          final probe = _Probe(
            (opened as Ok<QueryExecutor, DatabaseOpenFailure>).value,
          );
          runtime.track(probe.close);
          expect(
            (await probe.customSelect('SELECT * FROM labels').getSingle()).data,
            {
              'id': 71,
              'label': 'later',
              'reference': 'reference',
              'type': 'unknown',
              'origin': null,
            },
          );
          expect(
            (await probe.customSelect('SELECT * FROM frozen_utxos').getSingle())
                .data,
            {'wallet_id': 'orphan-origin', 'tx_id': 'frozen-tx', 'vout': 3},
          );
          expect(
            (await probe
                    .customSelect(
                      "SELECT seq FROM sqlite_sequence WHERE name='labels'",
                    )
                    .getSingle())
                .read<int>('seq'),
            99,
          );
          expect(
            (await probe
                    .customSelect('SELECT id FROM legacy_import_receipts')
                    .getSingle())
                .read<String>('id'),
            'split-v1/labels',
          );
          final electrumReopened = await electrumKeys.open(
            name: 'main',
            file: electrumFile,
            existingSchemaVersion: 1,
          );
          final liveElectrum = _Probe(
            (electrumReopened as Ok<QueryExecutor, DatabaseOpenFailure>).value,
          );
          runtime.track(liveElectrum.close);
          expect(
            await liveElectrum
                .customSelect(
                  "SELECT 1 FROM electrum_servers WHERE url='activated-owner-only'",
                )
                .get(),
            hasLength(1),
          );
          await runtime.close();
        }
        expect(source.existsSync(), isTrue);
        await source.rename('${source.path}.retained');
        expect(await cutover(activate: true).admit(), isA<Err>());
      },
    );
  }
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo> get allTables => const [];
}
