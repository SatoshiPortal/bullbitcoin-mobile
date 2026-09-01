import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
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
  test('new state starts without imported backup status', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final state = await database.select(database.recoverbullState).getSingle();
    expect(state.lastEncryptedBackupAt, isNull);
    expect(state.lastVerifiedEncryptedBackupAt, isNull);
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

    final before = DateTime.now().toUtc();
    await database.markEncryptedBackupStored();
    var state = await database.select(database.recoverbullState).getSingle();
    expect(state.lastEncryptedBackupAt, isA<DateTime>());
    expect(state.lastEncryptedBackupAt!.isAfter(before), isTrue);
    expect(state.lastVerifiedEncryptedBackupAt, isNull);

    final storeTime = state.lastEncryptedBackupAt;
    await database.markEncryptedBackupVerified();
    state = await database.select(database.recoverbullState).getSingle();
    expect(state.lastEncryptedBackupAt, storeTime);
    expect(state.lastVerifiedEncryptedBackupAt, isA<DateTime>());

    final verificationTime = state.lastVerifiedEncryptedBackupAt;
    await database.markEncryptedBackupStored();
    state = await database.select(database.recoverbullState).getSingle();
    expect(state.lastEncryptedBackupAt!.isAfter(storeTime!), isTrue);
    expect(state.lastVerifiedEncryptedBackupAt, isNull);
    expect(verificationTime, isA<DateTime>());
    await database.close();
  });

  test('verification records time without inventing a store time', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();

    await database.markEncryptedBackupVerified();
    final state = await database.select(database.recoverbullState).getSingle();
    expect(state.lastEncryptedBackupAt, isNull);
    expect(state.lastVerifiedEncryptedBackupAt, isA<DateTime>());
    await database.close();
  });

  test('a failed operation leaves lifecycle status unchanged', () async {
    final database = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await database.ensureState();
    final before = await database.select(database.recoverbullState).getSingle();

    try {
      throw StateError('operation failed');
    } catch (_) {}

    final after = await database.select(database.recoverbullState).getSingle();
    expect(after.lastEncryptedBackupAt, before.lastEncryptedBackupAt);
    expect(
      after.lastVerifiedEncryptedBackupAt,
      before.lastVerifiedEncryptedBackupAt,
    );
    await database.close();
  });

  test('default server is the production onion endpoint', () {
    expect(recoverBullDefaultServerUrl, startsWith('http://'));
    expect(recoverBullDefaultServerUrl, contains('.onion'));
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

  test('corruption recovery deletes only the explicit database file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-corrupt-',
    );
    final path = p.join(directory.path, 'state.sqlite');
    await File(path).writeAsString('not sqlite');
    await File('$path-other').writeAsString('keep sibling');

    final lifecycle = RecoverBullLifecycle();
    await lifecycle.openDatabase(path);

    expect(await File(path).exists(), isTrue);
    expect(await File('$path-other').readAsString(), 'keep sibling');
    await lifecycle.dispose();
    await directory.delete(recursive: true);
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

  test(
    'public setServer preserves monitored backups while resetting state',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'recoverbull-server-',
      );
      final path = p.join(directory.path, 'state.sqlite');
      final lifecycle = RecoverBullLifecycle();
      final database = await lifecycle.openDatabase(path);
      final store = RecoverBullAttemptMonitoringStore(database);
      await store.registerBackup(List<int>.filled(32, 1));
      await store.recordOwnAttempt(
        List<int>.filled(32, 1),
        serverTotalAttempts: 4,
        window: DateTime.utc(2026),
      );
      await database
          .update(database.recoverbullState)
          .write(
            RecoverbullStateCompanion(
              etag: const Value('etag'),
              collectionStartedAt: Value(DateTime.utc(2026)),
              lastSuccessfulCheckAt: Value(DateTime.utc(2026)),
            ),
          );

      final core = RecoverBullCore(
        config: RecoverBullConfig(databasePath: path),
        dependencies: const RecoverBullDependencies(),
        lifecycle: lifecycle,
      );
      await core.setServer(Uri.parse('http://newexample.onion'));

      final row = (await store.monitoredBackups()).single;
      expect(row.expectedServerDistinctCandidateTotal, 0);
      expect(row.currentWindow, 0);
      expect(row.lastWarningWindow, isNull);
      final state = await store.state();
      expect(state.etag, isNull);
      expect(state.collectionStartedAt, isNull);
      expect(state.lastSuccessfulCheckAt, isNull);
      await lifecycle.dispose();
      await directory.delete(recursive: true);
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
      'recoverbull_monitored_backup',
      'recoverbull_drive_backup_cache',
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
