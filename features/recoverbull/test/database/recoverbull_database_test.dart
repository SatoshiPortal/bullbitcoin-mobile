import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_network.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'dart:io';
import 'package:path/path.dart' as p;
import '../support/log_sink.dart';

final class _DatabaseTestRemote
    implements RecoverBullAttemptMonitoringRemotePort {
  RecoverBullAttemptsSnapshot? response;

  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) async => response;
}

void main() {
  test('a new database records no backup status on any network', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    for (final network in RecoverBullNetwork.values) {
      expect(await database.fetchBackupStatus(network), isNull);
    }
    await database.close();
  });

  test('a database replacing a corrupt one marks every network status '
      'lost', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState(initialBackupStatusLost: true);
    for (final network in RecoverBullNetwork.values) {
      final row = await database.fetchBackupStatus(network);
      expect(row!.statusLost, isTrue);
      expect(row.lastEncryptedBackupAt, isNull);
      expect(row.lastVerifiedEncryptedBackupAt, isNull);
    }
    await database.close();
  });

  test('initial permission seeds only a newly created database row', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-permission-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    final lifecycle = RecoverBullLifecycle();
    final first = await lifecycle.openDatabase(
      path,
      initialPermissionGranted: true,
    );
    expect(
      (await first.select(first.recoverbullState).getSingle())
          .permissionGranted,
      isTrue,
    );
    final second = await lifecycle.openDatabase(
      path,
      initialPermissionGranted: false,
    );
    expect(
      (await second.select(second.recoverbullState).getSingle())
          .permissionGranted,
      isTrue,
    );
    await lifecycle.dispose();
    await directory.delete(recursive: true);
  });

  test('storing records time and clears a previous verification', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    const network = RecoverBullNetwork.mainnet;

    final before = DateTime.now().toUtc();
    await database.markEncryptedBackupStored(network);
    var row = (await database.fetchBackupStatus(network))!;
    expect(row.lastEncryptedBackupAt, isA<DateTime>());
    expect(row.lastEncryptedBackupAt!.isAfter(before), isTrue);
    expect(row.lastVerifiedEncryptedBackupAt, isNull);

    final storeTime = row.lastEncryptedBackupAt;
    await database.markEncryptedBackupVerified(network);
    row = (await database.fetchBackupStatus(network))!;
    expect(row.lastEncryptedBackupAt, storeTime);
    expect(row.lastVerifiedEncryptedBackupAt, isA<DateTime>());

    final verificationTime = row.lastVerifiedEncryptedBackupAt;
    await database.markEncryptedBackupStored(network);
    row = (await database.fetchBackupStatus(network))!;
    expect(row.lastEncryptedBackupAt!.isAfter(storeTime!), isTrue);
    expect(row.lastVerifiedEncryptedBackupAt, isNull);
    expect(verificationTime, isA<DateTime>());
    await database.close();
  });

  test('verification records time without inventing a store time', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();

    await database.markEncryptedBackupVerified(RecoverBullNetwork.testnet);
    final row = (await database.fetchBackupStatus(RecoverBullNetwork.testnet))!;
    expect(row.lastEncryptedBackupAt, isNull);
    expect(row.lastVerifiedEncryptedBackupAt, isA<DateTime>());
    await database.close();
  });

  test('each network keeps its own backup status', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState(initialBackupStatusLost: true);

    await database.markEncryptedBackupStored(RecoverBullNetwork.testnet);

    final testnet = (await database.fetchBackupStatus(
      RecoverBullNetwork.testnet,
    ))!;
    expect(testnet.statusLost, isFalse);
    expect(testnet.lastEncryptedBackupAt, isA<DateTime>());
    final mainnet = (await database.fetchBackupStatus(
      RecoverBullNetwork.mainnet,
    ))!;
    expect(mainnet.statusLost, isTrue);
    expect(mainnet.lastEncryptedBackupAt, isNull);
    await database.close();
  });

  test('default server is the production onion endpoint', () {
    expect(recoverBullDefaultServerUrl, startsWith('http://'));
    expect(recoverBullDefaultServerUrl, contains('.onion'));
  });

  test('composition imports a legacy custom server URL', () async {
    final directory = await Directory.systemTemp.createTemp('recoverbull-url-');
    final lifecycle = RecoverBullLifecycle();

    try {
      final database = await lifecycle.openDatabase(
        p.join(directory.path, 'state.sqlite'),
        initialServerUrlOverride: Uri.parse('http://custom-server.onion'),
        initialPermissionGranted: true,
      );
      final datasource = RecoverbullSettingsDatasource(database: database);

      expect(await datasource.fetch(), Uri.parse('http://custom-server.onion'));
      expect(await datasource.fetchPermission(), isTrue);
    } finally {
      await lifecycle.dispose();
      await directory.delete(recursive: true);
    }
  });

  test('composition does not replace an existing server override', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState(
      initialServerUrlOverride: 'http://existing.onion',
    );
    await database.ensureState(initialServerUrlOverride: 'http://legacy.onion');

    final state = await database.select(database.recoverbullState).getSingle();

    expect(state.serverUrlOverride, 'http://existing.onion');
    await database.close();
  });

  test(
    'fresh settings fetch uses the configured effective default server',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final datasource = RecoverbullSettingsDatasource(
        database: database,
        defaultServer: Uri.parse(recoverBullDefaultServerUrl),
      );

      expect(await datasource.fetch(), Uri.parse(recoverBullDefaultServerUrl));
      await database.close();
    },
  );

  test('corruption recovery archives the database and sidecars', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-corrupt-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    await File(path).writeAsString('not sqlite');
    await File('$path-wal').writeAsString('wal');
    await File('$path-shm').writeAsString('shm');
    await File('$path-other').writeAsString('keep sibling');

    final lifecycle = RecoverBullLifecycle();
    await lifecycle.openDatabase(path);

    expect(await File(path).exists(), isTrue);
    final archived = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('.sqlite.corrupt-'))
        .map((file) => file.path)
        .toList();
    final databases = archived.where(
      (path) => RegExp(r'\.corrupt-\d+$').hasMatch(path),
    );
    expect(databases, hasLength(1));
    expect(await File(databases.single).readAsString(), 'not sqlite');
    // SQLite may remove sidecars on failed open depending on the platform.
    // Every surviving sidecar must belong to the same archived database.
    expect(
      archived,
      everyElement(
        isIn([
          databases.single,
          '${databases.single}-wal',
          '${databases.single}-shm',
          '${databases.single}-journal',
          '${databases.single}.sqlite-journal',
        ]),
      ),
    );
    expect(await File('$path-other').readAsString(), 'keep sibling');
    await lifecycle.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'a database reporting several integrity problems is archived and reopened',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-integrity-',
      );
      final path = p.join(directory.path, 'state.sqlite');
      _writeDatabaseWithStaleIndex(path);
      final raw = sqlite.sqlite3.open(path);
      expect(raw.select('PRAGMA integrity_check').length, greaterThan(1));
      raw.dispose();

      final lifecycle = RecoverBullLifecycle();
      addTearDown(() async {
        await lifecycle.dispose();
        await directory.delete(recursive: true);
      });
      final database = await lifecycle.openDatabase(path);

      expect(
        await database.customSelect('PRAGMA integrity_check').get(),
        hasLength(1),
      );
      expect(
        directory.listSync().whereType<File>().where(
          (file) => RegExp(r'\.corrupt-\d+$').hasMatch(file.path),
        ),
        hasLength(1),
      );
    },
  );

  test('concurrent first opens share one database connection', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-concurrent-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    final lifecycle = RecoverBullLifecycle();
    addTearDown(() async {
      await lifecycle.dispose();
      await directory.delete(recursive: true);
    });

    final opened = await Future.wait([
      lifecycle.openDatabase(path),
      lifecycle.openDatabase(path),
    ]);

    expect(identical(opened.first, opened.last), isTrue);
  });

  test('transient database failure preserves the existing path', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-transient-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    await Directory(path).create();

    final lifecycle = RecoverBullLifecycle();
    await expectLater(lifecycle.openDatabase(path), throwsA(isA<Exception>()));
    expect(await Directory(path).exists(), isTrue);
    await directory.delete(recursive: true);
  });

  test('corruption recovery keeps only the newest archive', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-archive-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    final firstLifecycle = RecoverBullLifecycle();
    final secondLog = TestLogSink.recording();
    final secondLifecycle = RecoverBullLifecycle(log: secondLog);
    addTearDown(() async {
      await firstLifecycle.dispose();
      await secondLifecycle.dispose();
      await directory.delete(recursive: true);
    });

    await File(path).writeAsString('first');
    await firstLifecycle.openDatabase(path);
    await firstLifecycle.dispose();
    await File(path).writeAsString('second');
    await secondLifecycle.openDatabase(path);

    final archives = directory.listSync().whereType<File>().where(
      (file) => file.path.contains('.sqlite.corrupt-'),
    );
    final databases = archives.where(
      (file) => RegExp(r'\.corrupt-\d+$').hasMatch(file.path),
    );
    expect(databases, hasLength(1));
    expect(await databases.single.readAsString(), 'second');
    expect(
      archives.map((file) => file.path),
      everyElement(
        isIn([
          databases.single.path,
          '${databases.single.path}-wal',
          '${databases.single.path}-shm',
          '${databases.single.path}-journal',
          '${databases.single.path}.sqlite-journal',
        ]),
      ),
    );
    expect(
      secondLog.entries.map((entry) => entry.message),
      contains('recoverbull.database.corrupt_archived'),
    );
  });

  test(
    'storing a changed server preserves identifiers and resets monitoring state',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      await store.registerBackup(List<int>.filled(32, 1));
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              etag: const Value('etag'),
              collectionStartedAt: Value(DateTime.utc(2026)),
              lastSuccessfulCheckAt: Value(DateTime.utc(2026)),
              consecutiveFailures: const Value(3),
              lastUnavailabilityWarningAt: Value(DateTime.utc(2026)),
            ),
          );
      final datasource = RecoverbullSettingsDatasource(
        database: database,
        defaultServer: Uri.parse(recoverBullDefaultServerUrl),
      );

      await datasource.store(Uri.parse('http://newexample.onion'));

      final state = await database
          .select(database.recoverbullState)
          .getSingle();
      expect(state.permissionGranted, isFalse);
      expect(state.etag, isNull);
      expect(state.collectionStartedAt, isNull);
      expect(state.lastSuccessfulCheckAt, isNull);
      expect(state.consecutiveFailures, 0);
      expect(state.lastUnavailabilityWarningAt, isNull);
      expect(state.generation, 1);
      expect(state.revision, 1);
      expect(await store.monitoredBackups(), hasLength(1));
      final remote = _DatabaseTestRemote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026, 1, 2),
          totalAttempts: {(await store.monitoredBackups()).single.digest: 1},
        );
      expect(
        await CheckBackupAttemptMonitoringUsecase(
          store: store,
          remote: remote,
          clock: () => DateTime.utc(2026, 1, 2, 1),
        ).execute(),
        isEmpty,
      );
      await database.close();
    },
  );

  test('schema has the monitoring tables and bundled sqlite is usable', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    final tables = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
        )
        .get();
    expect(tables.map((row) => row.read<String>('name')).toSet(), {
      'recoverbull_state',
      'recoverbull_backup_status',
      'recoverbull_monitored_backup',
      'recoverbull_drive_backup_cache',
      'recoverbull_acknowledged_alert',
    });
    expect(
      (await database.customSelect('SELECT sqlite_version()').getSingle())
          .read<String>('sqlite_version()'),
      isNotEmpty,
    );
    expect(sqlite.sqlite3.version.toString(), isNotEmpty);
    await database.close();
  });

  test(
    'attempt monitoring polling cannot overwrite the own-attempt baseline',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      final identifier = List<int>.generate(32, (index) => index);
      await store.registerBackup(identifier);
      final window = DateTime.utc(2026, 1, 1);
      await store.recordOwnAttempt(
        identifier,
        serverTotalAttempts: 4,
        window: window,
      );
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {identifier: 2},
        ),
      );
      final row = await database
          .select(database.recoverbullMonitoredBackup)
          .getSingle();
      expect(row.expectedServerDistinctCandidateTotal, 4);
      await database.close();
    },
  );

  test(
    'two independent connections preserve monotonic own-operation state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-attempt-monitoring-',
      );
      final path = p.join(directory.path, 'state.sqlite');
      final first = RecoverBullDatabase.open(path);
      final second = RecoverBullDatabase.open(path);
      await first.forceOpen();
      await second.forceOpen();
      final a = RecoverBullAttemptMonitoringStore(first);
      final b = RecoverBullAttemptMonitoringStore(second);
      final id = List<int>.filled(32, 7);
      await a.registerBackup(id);
      await Future.wait([
        a.recordOwnAttempt(
          id,
          serverTotalAttempts: 1,
          window: DateTime.utc(2026),
        ),
        b.recordOwnAttempt(
          id,
          serverTotalAttempts: 2,
          window: DateTime.utc(2026),
        ),
      ]);
      final row = await first
          .select(first.recoverbullMonitoredBackup)
          .getSingle();
      expect(row.expectedServerDistinctCandidateTotal, isIn([1, 2]));
      expect(row.rowRevision, 2);
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'disable and reset reject an in-flight snapshot without resurrection',
    () async {
      final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
      await database.ensureState();
      final store = RecoverBullAttemptMonitoringStore(database);
      final id = List<int>.filled(32, 8);
      await store.registerBackup(id);
      final token = await store.captureToken();
      await store.setEnabled(false);
      final result = await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026),
          totalAttempts: {id: 9},
        ),
        token,
      );
      expect(result.accepted, isFalse);
      expect(
        await database.select(database.recoverbullMonitoredBackup).get(),
        isEmpty,
      );
      await store.setEnabled(true);
      await store.registerBackup(id);
      final resetToken = await store.captureToken();
      await store.reset();
      expect(
        (await store.applySnapshot(
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: DateTime.utc(2026),
            totalAttempts: {id: 9},
          ),
          resetToken,
        )).accepted,
        isFalse,
      );
      expect(
        await database.select(database.recoverbullMonitoredBackup).get(),
        isEmpty,
      );
      await database.close();
    },
  );

  test(
    'a real poll in flight loses to a local attempt on another connection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-poll-',
      );
      final path = p.join(directory.path, 'state.sqlite');
      final first = RecoverBullDatabase.open(path);
      final second = RecoverBullDatabase.open(path);
      await first.forceOpen();
      await second.forceOpen();
      final a = RecoverBullAttemptMonitoringStore(first);
      final b = RecoverBullAttemptMonitoringStore(second);
      final id = List<int>.filled(32, 3);
      await a.registerBackup(id);
      final token = await a.captureToken();
      await b.recordOwnAttempt(
        id,
        serverTotalAttempts: 4,
        window: DateTime.utc(2026),
      );
      final result = await a.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026),
          totalAttempts: {id: 2},
        ),
        token,
      );
      expect(result.accepted, isTrue);
      expect(result.conflicts, 1);
      expect(
        (await a.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        4,
      );
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'a real poll in flight loses to disable on another connection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-disable-',
      );
      final path = p.join(directory.path, 'state.sqlite');
      final first = RecoverBullDatabase.open(path);
      final second = RecoverBullDatabase.open(path);
      await first.forceOpen();
      await second.forceOpen();
      final a = RecoverBullAttemptMonitoringStore(first);
      final b = RecoverBullAttemptMonitoringStore(second);
      final id = List<int>.filled(32, 4);
      await a.registerBackup(id);
      final token = await a.captureToken();
      await b.setEnabled(false);
      expect(
        (await a.applySnapshot(
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: DateTime.utc(2026),
            totalAttempts: {id: 9},
          ),
          token,
        )).accepted,
        isFalse,
      );
      expect(await a.monitoredBackups(), isEmpty);
      await first.close();
      await second.close();
      await directory.delete(recursive: true);
    },
  );

  test('a real poll in flight loses to an effective server change', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-server-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    final first = RecoverBullDatabase.open(path);
    final second = RecoverBullDatabase.open(path);
    await first.forceOpen();
    await second.forceOpen();
    final a = RecoverBullAttemptMonitoringStore(first);
    final id = List<int>.filled(32, 5);
    await a.registerBackup(id);
    final token = await a.captureToken();
    await second.transaction(() async {
      final state = await second.select(second.recoverbullState).getSingle();
      await second
          .update(second.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              serverUrlOverride: const Value('http://new.example'),
              generation: Value(state.generation + 1),
              revision: Value(state.revision + 1),
              etag: const Value(null),
            ),
          );
      await second.delete(second.recoverbullMonitoredBackup).go();
    });
    expect(
      (await a.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026),
          totalAttempts: {id: 9},
        ),
        token,
      )).accepted,
      isFalse,
    );
    expect(await a.monitoredBackups(), isEmpty);
    await first.close();
    await second.close();
    await directory.delete(recursive: true);
  });

  test('a real poll in flight loses to reset on another connection', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-reset-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    final first = RecoverBullDatabase.open(path);
    final second = RecoverBullDatabase.open(path);
    await first.forceOpen();
    await second.forceOpen();
    final a = RecoverBullAttemptMonitoringStore(first);
    final b = RecoverBullAttemptMonitoringStore(second);
    final id = List<int>.filled(32, 6);
    await a.registerBackup(id);
    final token = await a.captureToken();
    await b.reset();
    expect(
      (await a.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026),
          totalAttempts: {id: 9},
        ),
        token,
      )).accepted,
      isFalse,
    );
    expect(await a.monitoredBackups(), isEmpty);
    await first.close();
    await second.close();
    await directory.delete(recursive: true);
  });
}

/// Writes a structurally valid SQLite file whose index entries no longer match
/// their table rows, so `PRAGMA integrity_check` reports one row per mismatch.
void _writeDatabaseWithStaleIndex(String path) {
  final database = sqlite.sqlite3.open(path);
  final int pageSize;
  final int indexRoot;
  try {
    database.execute('CREATE TABLE t (a INTEGER, b TEXT)');
    database.execute('CREATE INDEX ib ON t (b)');
    for (var i = 0; i < 20; i++) {
      database.execute('INSERT INTO t VALUES (?, ?)', [i, 'value-$i']);
    }
    pageSize = database.select('PRAGMA page_size').single.values.single as int;
    indexRoot =
        database
                .select("SELECT rootpage FROM sqlite_master WHERE name = 'ib'")
                .single
                .values
                .single
            as int;
  } finally {
    database.dispose();
  }
  final file = File(path);
  final bytes = file.readAsBytesSync();
  final start = (indexRoot - 1) * pageSize;
  final needle = 'value-'.codeUnits;
  for (
    var offset = start;
    offset < start + pageSize - needle.length;
    offset++
  ) {
    var matches = true;
    for (var i = 0; i < needle.length; i++) {
      if (bytes[offset + i] != needle[i]) {
        matches = false;
        break;
      }
    }
    if (matches) bytes[offset] = 'V'.codeUnitAt(0);
  }
  file.writeAsBytesSync(bytes);
}
