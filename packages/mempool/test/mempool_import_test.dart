import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:legacy_storage/coordination.dart';
import 'package:legacy_storage/legacy_storage.dart';
import 'package:mempool/migration.dart';
import 'package:mempool/src/data/mempool_store.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:sqlite3/sqlite3.dart';

const defaults = [
  'main.example',
  'test.example',
  'liquid.example',
  'liquid-test.example',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final childDirectory = Platform.environment['S1A_TEST_DIRECTORY'];
  if (childDirectory != null) {
    test('crash child', () async {
      final directory = Directory(childDirectory);
      final entries = (jsonDecode(
        await File('${directory.path}/fixture-keystore.json').readAsString(),
      ) as Map<String, dynamic>).cast<String, String>();
      FakeSecureStoragePlatform(entries: entries).install();
      final keys = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => directory.path,
      ).databaseKeys(module: 'mempool');
      final lease = await NativeFileGate(
        File('${directory.path}/gate'),
      ).acquire(exclusive: true, timeout: Duration.zero) as ExclusiveAdmission;
      final step = Platform.environment['S1A_TEST_STEP'];
      final participant = MempoolImport(
        file: File('${directory.path}/mempool.sqlite'),
        defaultServers: defaults,
        testingKeys: keys,
        checkpoint: (point) async {
          if (point == step) {
            final pending = File('${directory.path}/checkpoint.tmp');
            await pending.writeAsString('$pid', flush: true);
            await pending.rename('${directory.path}/checkpoint');
            await Completer<void>().future;
          }
        },
      );
      final owner = (await participant.prepare(
        lease,
        OwnerOrigin.fresh,
      ) as Ok<PreparedOwner, LegacyImportFailure>).value;
      if (step != null && step.startsWith('import')) {
        expect(
          await owner.importLegacy(
            LegacySource(File('${directory.path}/legacy.sqlite'), 16),
          ),
          isA<Ok>(),
        );
      } else {
        expect(await owner.initializeFresh(), isA<Ok>());
      }
      expect(await owner.close(), isA<Ok>());
      await lease.close();
    });
    return;
  }

  late Directory directory;
  late FakeSecureStoragePlatform keystore;
  late DatabaseKeys keys;
  late NativeFileGate gate;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mempool-import-');
    keystore = FakeSecureStoragePlatform()..install();
    keys = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => directory.path,
    ).databaseKeys(module: 'mempool');
    gate = NativeFileGate(File('${directory.path}/gate'));
  });
  tearDown(() async {
    await LifecycleAdmission.retryQuarantined();
    await directory.delete(recursive: true);
  });

  MempoolImport participant() => MempoolImport(
    file: File('${directory.path}/mempool.sqlite'),
    defaultServers: defaults,
    testingKeys: keys,
  );

  Future<PreparedOwner> prepare(ExclusiveAdmission lease) async {
    final prepared = await participant().prepare(lease, OwnerOrigin.legacy);
    expect(prepared, isA<Ok>());
    return (prepared as Ok<PreparedOwner, LegacyImportFailure>).value;
  }

  void legacy({bool empty = false}) {
    final db = sqlite3.open('${directory.path}/legacy.sqlite');
    db.execute(
      'CREATE TABLE mempool_servers (url TEXT NOT NULL,is_testnet INTEGER NOT NULL,is_liquid INTEGER NOT NULL,is_custom INTEGER NOT NULL,enable_ssl INTEGER NOT NULL DEFAULT 1,PRIMARY KEY(url,is_testnet,is_liquid))',
    );
    db.execute(
      'CREATE TABLE mempool_settings (network TEXT PRIMARY KEY NOT NULL,use_for_fee_estimation INTEGER NOT NULL DEFAULT 1)',
    );
    if (!empty) {
      db.execute(
        "INSERT INTO mempool_servers VALUES ('EXACT.example/path',1,0,1,0)",
      );
      db.execute(
        "INSERT INTO mempool_settings VALUES ('unknown-future-network',0)",
      );
    }
    db.userVersion = 16;
    db.close();
  }

  Future<void> verify({required bool fresh, bool empty = false}) async {
    final shared = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    expect(
      await participant().inspect(shared),
      isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
        (r) => r.value,
        'readiness',
        fresh ? OwnerReadiness.initialized : OwnerReadiness.imported,
      ),
    );
    final opened = await MempoolStore.open(
      File('${directory.path}/mempool.sqlite'),
      shared,
      existing: true,
      testingKeys: keys,
    );
    final store = (opened as Ok<MempoolStore, DatabaseOpenFailure>).value;
    final servers = await store.database
        .customSelect('SELECT * FROM mempool_servers')
        .get();
    final settings = await store.database
        .customSelect('SELECT * FROM mempool_settings')
        .get();
    if (fresh) {
      expect(servers.length, 4);
      expect(settings.length, 4);
    } else if (empty) {
      expect(servers, isEmpty);
      expect(settings, isEmpty);
    } else {
      expect(servers.single.data, {
        'url': 'EXACT.example/path',
        'is_testnet': 1,
        'is_liquid': 0,
        'is_custom': 1,
        'enable_ssl': 0,
      });
      expect(settings.single.data, {
        'network': 'unknown-future-network',
        'use_for_fee_estimation': 0,
      });
    }
    await shared.close();
  }

  for (final empty in [false, true]) {
    test(
      'imports every column exactly, empty=$empty, receipt prevents source reread',
      () async {
        legacy(empty: empty);
        final lease = await gate.acquire(
          exclusive: true,
          timeout: Duration.zero,
        ) as ExclusiveAdmission;
        final owner = await prepare(lease);
        final source = LegacySource(
          File('${directory.path}/legacy.sqlite'),
          16,
        );
        expect(await owner.importLegacy(source), isA<Ok>());
        await source.file.delete();
        expect(await owner.importLegacy(source), isA<Ok>());
        expect(await owner.importLegacy(source), isA<Ok>());
        expect(await owner.close(), isA<Ok>());
        await lease.close();
        await verify(fresh: false, empty: empty);
      },
    );
  }

  test(
    'a verified runtime store is consumed once by its own admission',
    () async {
      final exclusive = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      final owner = await prepare(exclusive);
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
      await exclusive.close();

      final participant = MempoolImport(
        file: File('${directory.path}/mempool.sqlite'),
        defaultServers: defaults,
        testingKeys: keys,
        retainRuntimeStore: true,
      );
      final first = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      addTearDown(first.close);
      final other = await gate.acquire(
        exclusive: false,
        timeout: Duration.zero,
      ) as RuntimeAdmission;
      addTearDown(other.close);

      expect(await participant.inspect(first), isA<Ok>());
      expect(participant.takeRuntimeStore(other), isNull);
      final store = participant.takeRuntimeStore(first);
      if (store == null) {
        fail('The admission must keep the verified store open');
      }
      expect(participant.takeRuntimeStore(first), isNull);
      expect(await store.database.customSelect('SELECT 1').get(), hasLength(1));

      expect(await participant.inspect(other), isA<Ok>());
      await other.close();
      expect(participant.takeRuntimeStore(other), isNull);
      await first.close();
      final next = await gate.acquire(exclusive: true, timeout: Duration.zero);
      await next.close();
    },
  );

  test(
    'pending schema is not readiness and fresh initialization is atomic',
    () async {
      final lease = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      final owner = await prepare(lease);
      expect(
        await owner.receipt(),
        isA<Ok<OwnerReadiness, LegacyImportFailure>>().having(
          (r) => r.value,
          'pending',
          OwnerReadiness.pending,
        ),
      );
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.initializeFresh(), isA<Ok>());
      expect(await owner.close(), isA<Ok>());
      await lease.close();
      await verify(fresh: true);
    },
  );

  test('existing encrypted file with missing key is preserved', () async {
    final lease = await gate.acquire(
      exclusive: true,
      timeout: Duration.zero,
    ) as ExclusiveAdmission;
    final owner = await prepare(lease);
    expect(await owner.initializeFresh(), isA<Ok>());
    expect(await owner.close(), isA<Ok>());
    await lease.close();
    final file = File('${directory.path}/mempool.sqlite');
    final before = await file.readAsBytes();
    keystore.entries.clear();
    final shared = await gate.acquire(
      exclusive: false,
      timeout: Duration.zero,
    ) as RuntimeAdmission;
    expect(await participant().inspect(shared), isA<Err>());
    await shared.close();
    expect(await file.readAsBytes(), before);
    expect(keystore.entries, isEmpty);
  });

  test(
    'locked keystore is deferred and orphan WAL cannot provision a key',
    () async {
      final lease = await gate.acquire(
        exclusive: true,
        timeout: Duration.zero,
      ) as ExclusiveAdmission;
      keystore.locked = true;
      expect(
        await participant().prepare(lease, OwnerOrigin.fresh),
        isA<Err<PreparedOwner, LegacyImportFailure>>().having(
          (r) => r.failure,
          'deferred',
          isA<LegacyImportDeferred>(),
        ),
      );
      keystore.locked = false;
      await File('${directory.path}/mempool.sqlite-wal')
          .writeAsString('orphan');
      expect(await participant().prepare(lease, OwnerOrigin.fresh), isA<Err>());
      expect(keystore.entries, isEmpty);
      expect(File('${directory.path}/mempool.sqlite').existsSync(), isFalse);
      await lease.close();
    },
  );

  test(
    'later Mempool edits survive two imports with a committed receipt',
    () async {
      legacy();
      final source = LegacySource(File('${directory.path}/legacy.sqlite'), 16);
      for (var iteration = 0; iteration < 3; iteration++) {
        final lease = await gate.acquire(
          exclusive: true,
          timeout: Duration.zero,
        ) as ExclusiveAdmission;
        final owner = await prepare(lease);
        expect(await owner.importLegacy(source), isA<Ok>());
        expect(await owner.close(), isA<Ok>());
        final opened = await MempoolStore.open(
          File('${directory.path}/mempool.sqlite'),
          lease,
          existing: true,
          testingKeys: keys,
        );
        final store = (opened as Ok<MempoolStore, DatabaseOpenFailure>).value;
        if (iteration == 0) {
          await store.database.customStatement(
            'UPDATE mempool_settings SET use_for_fee_estimation = 1',
          );
        }
        expect(
          (await store.database
                  .customSelect(
                    'SELECT use_for_fee_estimation FROM mempool_settings',
                  )
                  .getSingle())
              .read<int>('use_for_fee_estimation'),
          1,
        );
        await lease.close();
      }
    },
  );

  for (final step in [
    'fresh-schema',
    'fresh-seeds',
    'fresh-receipt',
    'fresh-commit',
    'import-rows',
    'import-verify',
    'import-commit',
  ]) {
    test('pilot SIGKILL at $step replays twice', () async {
      final fresh = step.startsWith('fresh');
      if (!fresh) legacy();
      expect(await keys.getOrCreate(name: 'main'), isA<Ok>());
      // Disposable, generated test DEK only; never an application/user key.
      await File('${directory.path}/fixture-keystore.json')
          .writeAsString(jsonEncode(keystore.entries), flush: true);
      final child = await Process.start(
        'fvm',
        [
          'flutter',
          'test',
          'test/mempool_import_test.dart',
          '--reporter',
          'expanded',
        ],
        environment: {
          'S1A_TEST_DIRECTORY': directory.path,
          'S1A_TEST_STEP': step,
        },
      );
      final output = child.stdout.transform(utf8.decoder).join();
      final errors = child.stderr.transform(utf8.decoder).join();
      final checkpoint = File('${directory.path}/checkpoint');
      final timer = Stopwatch()..start();
      try {
        while (!await checkpoint.exists() &&
            timer.elapsed < const Duration(seconds: 90)) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        if (!await checkpoint.exists()) {
          child.kill();
          fail(
            'Pilot child missed checkpoint: ${await output} ${await errors}',
          );
        }
        final childPid = int.parse(await checkpoint.readAsString());
        expect(Process.killPid(childPid, ProcessSignal.sigkill), isTrue);
        expect(await child.exitCode, isNot(0));
      } finally {
        child.kill();
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        final lease = await gate.acquire(
          exclusive: true,
          timeout: Duration.zero,
        ) as ExclusiveAdmission;
        final owner = await prepare(lease);
        expect(
          fresh
              ? await owner.initializeFresh()
              : await owner.importLegacy(
                  LegacySource(File('${directory.path}/legacy.sqlite'), 16),
                ),
          isA<Ok>(),
        );
        expect(await owner.close(), isA<Ok>());
        await lease.close();
      }
      await verify(fresh: fresh);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}
