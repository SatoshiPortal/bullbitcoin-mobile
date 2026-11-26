import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electrum/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mempool/migration.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../../packages/legacy_storage/test/migrations_test/bull_database/generated/schema_v15.dart'
    as v15;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final freshPilot in [false, true]) {
    test(
      'Electrum imports ${freshPilot ? 'later writes from fresh S1a' : 'published v15'} without replacing source',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'electrum-cutover-',
        );
        addTearDown(() async {
          await LifecycleAdmission.retryQuarantined();
          await directory.delete(recursive: true);
        });
        FakeSecureStoragePlatform().install();
        final secrets = Secrets(scratchDirectory: () async => directory.path);
        final source = File('${directory.path}/legacy.sqlite');
        final expectedNetwork = freshPilot
            ? 'unknown-network'
            : 'bitcoinTestnet';
        Future<void> writeFixture(GeneratedDatabase database) async {
          await database.customStatement(
            freshPilot
                ? "INSERT INTO electrum_servers VALUES ('custom-later.example','unknown-network',71,1)"
                : "INSERT INTO electrum_servers VALUES ('custom-later.example',1,0,71,1)",
          );
          await database.customStatement(
            "INSERT INTO transactions VALUES ('cache-later',2,'00042','21',0,' [ ] ',' [] ',NULL,NULL,0,NULL,NULL)",
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
        final file = File('${directory.path}/electrum.sqlite');
        final keys = secrets.databaseKeys(module: 'electrum');
        final participant = createElectrumImportForTesting(
          file: file,
          keys: keys,
        );
        StorageCutover cutover({required bool activate}) => StorageCutover(
          directory: Directory('${directory.path}/coordination'),
          legacy: legacy,
          expectedOwners: splitV1Owners,
          destinationFamilies: [file, File('${directory.path}/mempool.sqlite')],
          participants: [mempool, if (activate) participant],
        );
        // A prior slice establishes legacy provenance even for fresh installs.
        final first = await cutover(activate: false).prepare();
        expect(first, isA<Ok>());
        final admission =
            (first as Ok<RuntimeAdmission, LegacyImportFailure>).value;
        if (freshPilot) await writeFixture(await legacy.open(admission));
        await admission.close();
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
            (await probe
                    .customSelect(
                      'SELECT * FROM electrum_servers WHERE network = ?',
                      variables: [Variable(expectedNetwork)],
                    )
                    .getSingle())
                .data,
            {
              'url': 'custom-later.example',
              'network': expectedNetwork,
              'priority': 71,
              'is_custom': 1,
            },
          );
          expect(
            (await probe
                    .customSelect(
                      "SELECT size,vin,height FROM transactions WHERE txid='cache-later'",
                    )
                    .getSingle())
                .data,
            {'size': '00042', 'vin': ' [ ] ', 'height': null},
          );
          expect(
            (await probe
                    .customSelect('SELECT id FROM legacy_import_receipts')
                    .getSingle())
                .read<String>('id'),
            'split-v1/electrum',
          );
          await runtime.close();
        }
        expect(source.existsSync(), isTrue);
        final retained = await source.rename('${source.path}.retained');
        expect(await cutover(activate: true).admit(), isA<Err>());
        await retained.rename(source.path);

        await file.delete();
        expect(await cutover(activate: true).admit(), isA<Err>());
        expect(
          await cutover(activate: true).prepare(),
          isA<Err<RuntimeAdmission, LegacyImportFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<LegacyOwnerFailure>().having(
              (failure) => failure.cause,
              'cause',
              LegacyOwnerFailureCause.missingAfterAdmission,
            ),
          ),
        );
        expect(file.existsSync(), isFalse);
        expect(source.existsSync(), isTrue);
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
