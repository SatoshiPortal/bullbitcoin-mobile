import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/background_bootstrap.dart';
import 'package:bb_mobile/storage_owner_manifest.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:drift/drift.dart' show GeneratedDatabase;
import 'package:drift/native.dart';
import 'package:electrum/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/app_database.dart' show SqliteDatabase;
import 'package:legacy_storage/coordination.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:secrets/migration.dart' show SecretsImport;
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

import '../packages/legacy_storage/test/migrations_test/bull_database/generated/schema_v14.dart'
    as v14;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'wallet dispatch retries before opening owners until the source is current',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'background-electrum-',
      );
      final previousPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(directory.path);
      addTearDown(() async {
        await log.flush();
        PathProviderPlatform.instance = previousPaths;
        await directory.delete(recursive: true);
      });
      final secure = FakeSecureStoragePlatform().install();
      File file(String name) => File('${directory.path}/$name');
      final source = file('bullbitcoin_sqlite.sqlite');
      final coordination = Directory('${directory.path}/storage-coordination');
      final inventory = file('databases/secrets.sqlite');
      final electrum = file('databases/electrum.sqlite');
      final preferences = file('databases/preferences.sqlite');
      final legacy = LegacySourceStore(
        source: LegacySource(source, SqliteDatabase.currentSchemaVersion),
        create: SqliteDatabase.new,
      );
      await _seedLabel(SqliteDatabase(NativeDatabase(source)));
      final prepared = await StorageCutover(
        directory: coordination,
        legacy: legacy,
        expectedOwners: storageOwnerManifest,
        participants: [
          SecretsImport(file: inventory),
          createElectrumImportForTesting(
            file: electrum,
            keys: Secrets(
              authority: unlockedSessionAuthority(),
              scratchDirectory: () async => directory.path,
            ).databaseKeys(module: 'electrum'),
          ),
        ],
      ).prepare();
      final runtime = prepared.fold(
        (admission) => admission,
        (failure) => fail('Fixture preparation failed: ${failure.runtimeType}'),
      );
      await runtime.close();
      // Keep the Electrum receipt in the marker but withhold its file so a
      // current source reaches the Electrum state check without a plugin call.
      await electrum.rename(file('electrum.fixture').path);

      final oldSource = file('legacy-v14.fixture');
      await _seedLabel(v14.DatabaseAtV14(NativeDatabase(oldSource)));
      final marker = file('storage-coordination/split-v1.json');
      final watched = [
        for (final database in [source, inventory, electrum, preferences])
          for (final suffix in [
            '',
            '-wal',
            '-shm',
            '-journal',
            '.retire-pending',
          ])
            File('${database.path}$suffix'),
        marker,
        File('${marker.path}.tmp'),
      ];
      Map<String, List<int>?> snapshot() => {
        for (final item in watched)
          item.path: item.existsSync() ? item.readAsBytesSync() : null,
      };

      Future<void> expectRetry({required bool reachedOwners}) async {
        final before = snapshot();
        final keyReads = secure.reads;
        // The missing main file forces the owner's state check to try this
        // sidecar. Observe that lookup without substituting filesystem I/O.
        final probes = _ElectrumProbe('${electrum.path}-wal');
        var returnedRunner = false;
        const task = BackgroundTask.walletsSync;
        final acknowledged = await IOOverrides.runWithIOOverrides(
          () => mapBackgroundTaskResult(task.name, (task) async {
            final runner = await bootstrapAdmittedBackgroundRunner(
              task,
              clock: Stopwatch()..start(),
            );
            returnedRunner = runner.handlers.containsKey(task);
            return runner;
          }),
          probes,
        );
        expect(
          returnedRunner,
          isTrue,
          reason: 'retry must come from the runner',
        );
        expect(acknowledged, isFalse, reason: 'WorkManager should retry');
        expect(probes.visited, reachedOwners, reason: 'Electrum family probe');
        if (reachedOwners) {
          expect(secure.reads, greaterThan(keyReads), reason: 'Secrets opened');
        } else {
          expect(secure.reads, keyReads, reason: 'no owner key accessed');
          expect(snapshot(), before, reason: 'storage families are unchanged');
        }
        expect(electrum.existsSync(), isFalse);
        expect(preferences.existsSync(), isFalse);
        final exclusive = await NativeFileGate(
          File('${coordination.path}/lifecycle.lock'),
        ).acquire(exclusive: true, timeout: Duration.zero);
        await exclusive.close();
      }

      _expectLabel(source, version: SqliteDatabase.currentSchemaVersion);
      await expectRetry(reachedOwners: true);

      final current = await source.rename(file('legacy-v16.fixture').path);
      await expectRetry(reachedOwners: false);
      expect(source.existsSync(), isFalse);

      await oldSource.rename(source.path);
      _expectLabel(source, version: 14);
      await expectRetry(reachedOwners: false);
      _expectLabel(source, version: 14);

      await source.rename(oldSource.path);
      await current.rename(source.path);
      await expectRetry(reachedOwners: true);
      _expectLabel(source, version: SqliteDatabase.currentSchemaVersion);
    },
  );
}

Future<void> _seedLabel(GeneratedDatabase database) async {
  try {
    await database.customStatement(
      "INSERT INTO labels (label, reference, type, origin) "
      "VALUES ('fixture label', 'fixture-reference', 'tx', 'fixture-wallet')",
    );
  } finally {
    await database.close();
  }
}

void _expectLabel(File file, {required int version}) {
  final database = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    expect(database.userVersion, version);
    expect(database.select('SELECT label, reference FROM labels').single, {
      'label': 'fixture label',
      'reference': 'fixture-reference',
    });
  } finally {
    database.close();
  }
}

final class _ElectrumProbe extends IOOverrides {
  final String sidecar;
  bool visited = false;

  _ElectrumProbe(this.sidecar);

  @override
  File createFile(String path) {
    if (path == sidecar) visited = true;
    return super.createFile(path);
  }
}

final class _Paths extends PathProviderPlatform {
  final String path;
  _Paths(this.path);

  @override
  Future<String> getApplicationDocumentsPath() async => path;

  @override
  Future<String> getApplicationSupportPath() async => path;
}
