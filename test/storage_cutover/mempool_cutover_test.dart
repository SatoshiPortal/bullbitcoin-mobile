import 'dart:io';

import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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
  test(
    'foreground upgrades published v15 then imports Mempool before runtime',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mempool-published-upgrade-',
      );
      final source = File('${directory.path}/legacy.sqlite');
      final old = v15.DatabaseAtV15(NativeDatabase(source));
      await old.customStatement(
        "INSERT INTO mempool_servers VALUES ('custom.example',1,0,1,0)",
      );
      await old.customStatement(
        "INSERT INTO mempool_settings VALUES ('unknown-network',0)",
      );
      await old.close();
      FakeSecureStoragePlatform().install();
      final keys = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      ).databaseKeys(module: 'mempool');
      final file = File('${directory.path}/mempool.sqlite');
      final participant = MempoolImport(
        file: file,
        defaultServers: ['a', 'b', 'c', 'd'],
        testingKeys: keys,
      );
      final sourceStore = LegacySourceStore(
        source: LegacySource(source, 16),
        create: SqliteDatabase.new,
      );
      final coordinator = StorageCutover(
        directory: Directory('${directory.path}/coordination'),
        legacy: sourceStore,
        expectedOwners: splitV1Owners,
        participants: [participant],
      );
      for (var attempt = 0; attempt < 2; attempt++) {
        final result = await coordinator.prepare();
        expect(result, isA<Ok>());
        final runtime =
            (result as Ok<RuntimeAdmission, LegacyImportFailure>).value;
        expect(
          await participant.inspect(runtime),
          isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
            (r) => r.value,
            'readiness',
            OwnerReadiness.imported,
          ),
        );
        final legacy = await sourceStore.open(runtime);
        expect(
          (await legacy.customSelect('PRAGMA user_version').getSingle())
              .read<int>('user_version'),
          16,
        );
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
          (await probe.customSelect('SELECT * FROM mempool_servers').get())
              .single
              .data,
          {
            'url': 'custom.example',
            'is_testnet': 1,
            'is_liquid': 0,
            'is_custom': 1,
            'enable_ssl': 0,
          },
        );
        expect(
          (await probe.customSelect('SELECT * FROM mempool_settings').get())
              .single
              .data,
          {'network': 'unknown-network', 'use_for_fee_estimation': 0},
        );
        await runtime.close();
      }
      expect(source.existsSync(), isTrue);
      await directory.delete(recursive: true);
    },
  );
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo> get allTables => const [];
}
