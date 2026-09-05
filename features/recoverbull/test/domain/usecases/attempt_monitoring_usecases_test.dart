import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart' as public;
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_alert.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/acknowledge_attempt_alert_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/is_recoverbull_attempt_monitoring_enabled_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/set_recoverbull_attempt_monitoring_enabled_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/discover_drive_backups_usecase.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_drive_discovery_port.dart';
import 'package:bull_recoverbull/src/attempt_monitoring/recoverbull_attempt_monitoring.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

class _Remote implements RecoverBullAttemptMonitoringRemotePort {
  RecoverBullAttemptsSnapshot? response;
  int calls = 0;
  String? lastEtag;

  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) async {
    calls++;
    lastEtag = etag;
    return response;
  }
}

final class _DriveDiscovery implements RecoverBullDriveDiscoveryPort {
  const _DriveDiscovery();

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  ) => action(
    _TestDiscoverySession(account: 'account', files: files, content: content),
  );

  Future<String> account() async => 'account';

  Future<List<RecoverBullDriveFile>> files() async => [
    RecoverBullDriveFile(id: 'file', createdTime: DateTime.utc(2026)),
  ];

  Future<String> content(String fileId) async =>
      _validVault('000102030405060708090a0b0c0d0e0f');
}

final class _CountingDrive implements RecoverBullDriveDiscoveryPort {
  int contentCalls = 0;
  final String currentAccount;
  final String fileId;
  final String backupId;

  _CountingDrive(this.currentAccount, this.fileId, this.backupId);

  @override
  Future<T> withDiscoverySession<T>(
    Future<T> Function(RecoverBullDriveDiscoverySession? session) action,
  ) => action(
    _TestDiscoverySession(
      account: currentAccount,
      files: files,
      content: content,
    ),
  );

  Future<String> account() async => currentAccount;

  Future<List<RecoverBullDriveFile>> files() async => [
    RecoverBullDriveFile(id: fileId, createdTime: DateTime.utc(2026)),
  ];

  Future<String> content(String fileId) async {
    contentCalls++;
    return _validVault(backupId);
  }
}

final class _TestDiscoverySession implements RecoverBullDriveDiscoverySession {
  @override
  final String account;
  final Future<List<RecoverBullDriveFile>> Function() _files;
  final Future<String> Function(String) _content;

  const _TestDiscoverySession({
    required this.account,
    required this._files,
    required this._content,
  });

  @override
  Future<List<RecoverBullDriveFile>> files() => _files();

  @override
  Future<String> content(String fileId) => _content(fileId);
}

void main() {
  final id = List<int>.generate(16, (i) => i);
  final window = DateTime.utc(2026, 8, 5, 14, 37, 22);

  Future<(RecoverBullDatabase, RecoverBullAttemptMonitoringStore)>
  build() async {
    final db = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await db.ensureState();
    return (db, RecoverBullAttemptMonitoringStore(db));
  }

  test('registering a backup does not count an attempt', () async {
    final (db, store) = await build();
    await RegisterMonitoredBackupUsecase(store).execute(
      backupIdHex: id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
    expect(
      (await store.monitoredBackups())
          .single
          .expectedServerDistinctCandidateTotal,
      0,
    );
    await db.close();
  });

  test('startup drive discovery adopts each returned backup', () async {
    final (db, store) = await build();
    await DiscoverDriveBackupsUsecase(
      drive: const _DriveDiscovery(),
      store: store,
    ).execute();
    final row = (await store.monitoredBackups()).single;
    expect(row.expectedServerDistinctCandidateTotal, 0);
    expect(row.lastWarningWindow, 0);
    await db.close();
  });

  test(
    'drive discovery caches file content and purges only old drive rows',
    () async {
      final (db, store) = await build();
      final drive = _CountingDrive(
        'old-account',
        'file',
        '101112131415161718191a1b1c1d1e1f',
      );
      final discovery = DiscoverDriveBackupsUsecase(drive: drive, store: store);
      await discovery.execute();
      await discovery.execute();
      expect(drive.contentCalls, 1);
      await store.registerBackup(
        List<int>.filled(16, 7),
        origin: MonitoredBackupOrigin.adopted,
      );
      final next = _CountingDrive(
        'new-account',
        'new-file',
        '202122232425262728292a2b2c2d2e2f',
      );
      await DiscoverDriveBackupsUsecase(drive: next, store: store).execute();
      final rows = await store.monitoredBackups();
      expect(rows, hasLength(2));
      expect(rows.where((row) => row.driveAccount == 'old-account'), isEmpty);
      expect(rows.where((row) => row.driveAccount == null), hasLength(1));
      await db.close();
    },
  );

  test('adopting a backup seeds its observed baseline and window', () async {
    final (db, store) = await build();
    await store.registerBackup(
      id,
      origin: MonitoredBackupOrigin.adopted,
      observedTotal: 3,
      window: attemptWindowIdentity(window),
    );
    final row = (await store.monitoredBackups()).single;
    expect(row.expectedServerDistinctCandidateTotal, 3);
    expect(row.currentWindow, attemptWindowIdentity(window));
    expect(row.lastWarningWindow, attemptWindowIdentity(window));
    await db.close();
  });

  test('adopted baseline stays silent until the next server attempt', () async {
    final (db, store) = await build();
    await store.registerBackup(
      id,
      origin: MonitoredBackupOrigin.adopted,
      observedTotal: 3,
      window: attemptWindowIdentity(window),
    );
    final digest = (await store.monitoredBackups()).single.digest;
    var now = DateTime.now().toUtc();
    final check = CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 3},
          windowStartedAt: {digest: window},
        ),
      clock: () => now,
    );
    expect(await check.execute(), isEmpty);
    (check.remote as _Remote).response = RecoverBullAttemptsSnapshot(
      collectionStartedAt: window,
      totalAttempts: {digest: 4},
      windowStartedAt: {digest: window},
    );
    now = now.add(const Duration(hours: 2));
    expect((await check.execute()).single, isA<SuspiciousActivityAlert>());
    await db.close();
  });

  test('created baseline alerts on its first server attempt', () async {
    final (db, store) = await build();
    await store.registerBackup(id, origin: MonitoredBackupOrigin.created);
    final digest = (await store.monitoredBackups()).single.digest;
    final alerts = await CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 1},
          windowStartedAt: {digest: window},
        ),
    ).execute();
    expect(alerts.single, isA<SuspiciousActivityAlert>());
    await db.close();
  });

  test('status recording uses the server total as the baseline', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await RecordLocalAttemptUsecase(store).execute(
      backupIdHex: id.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      attemptStatus: KeyServerAttemptStatus(
        totalAttempts: 2,
        failedAttempts: 1,
        remainingAttempts: 1,
        windowStartedAt: window,
        previousAttemptAt: null,
        resetsAt: window.add(const Duration(days: 1)),
      ),
    );
    expect(
      (await store.monitoredBackups())
          .single
          .expectedServerDistinctCandidateTotal,
      2,
    );
    await db.close();
  });

  test('snapshot excess produces one warning and deduplicates it', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final digest = (await store.monitoredBackups()).single.digest;
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
        totalAttempts: {digest: 2},
        windowStartedAt: {digest: window},
        etag: 'one',
      );
    final check = CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: remote,
      clock: () => DateTime.utc(2026, 8, 5, 15),
    );
    final first = await check.execute();
    expect(first.single, isA<SuspiciousActivityAlert>());
    final second = await check.execute();
    expect(second, isEmpty);
    await db.close();
  });

  test('matching server total stays silent', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final digest = (await store.monitoredBackups()).single.digest;
    await store.recordStatus(
      id,
      KeyServerAttemptStatus(
        totalAttempts: 2,
        failedAttempts: 0,
        remainingAttempts: 1,
        windowStartedAt: window,
        previousAttemptAt: null,
        resetsAt: window,
      ),
    );
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
        totalAttempts: {digest: 2},
        windowStartedAt: {digest: window},
      );
    expect(
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
      ).execute(),
      isEmpty,
    );
    await db.close();
  });

  test('304 is accepted and refreshes successful-check time', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        totalAttempts: {},
        notModified: true,
      );
    await CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: remote,
    ).execute();
    expect((await store.state()).lastSuccessfulCheckAt, isNotNull);
    await db.close();
  });

  test(
    'a real collection followed by 304 preserves monitored backups and emits no wipe alert',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final digest = (await store.monitoredBackups()).single.digest;
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 2},
        ),
      );
      final now = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
          totalAttempts: const {},
          notModified: true,
        );
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => now,
      ).execute();
      expect(await store.monitoredBackups(), hasLength(1));
      expect((await store.state()).collectionStartedAt, window);
      await db.close();
    },
  );

  test(
    'a real collection followed by service busy preserves monitored backups and counts a poll failure',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final digest = (await store.monitoredBackups()).single.digest;
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 2},
        ),
      );
      final previousSuccessfulCheck =
          (await store.state()).lastSuccessfulCheckAt;
      final now = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          ),
          totalAttempts: const {},
          serviceBusy: true,
        );
      final alerts = await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => now,
      ).execute();
      expect(alerts, contains(isA<ServicePressureAlert>()));
      expect((await store.state()).consecutiveFailures, 1);
      expect(
        (await store.state()).lastSuccessfulCheckAt,
        previousSuccessfulCheck,
      );
      expect(await store.monitoredBackups(), hasLength(1));
      await db.close();
    },
  );

  test(
    'collection timestamp comparison ignores sub-second round-trip precision',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: window.add(const Duration(microseconds: 456)),
          totalAttempts: const {},
        ),
      );
      final now = DateTime.now().toUtc().add(const Duration(minutes: 2));
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window.add(const Duration(microseconds: 123)),
          totalAttempts: const {},
        );
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => now,
      ).execute();
      expect(await store.monitoredBackups(), hasLength(1));
      await db.close();
    },
  );

  test(
    'concurrent status and replacement preserve monotonic row revisions',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final digest = (await store.monitoredBackups()).single.digest;
      await Future.wait([
        store.recordStatus(id, _status(2)),
        store.replaceBackup(
          AttemptMonitoringBackupState(
            serverUrl: '',
            backupIdHash: _hex(digest),
            expectedTotalAttempts: 3,
            currentWindow: 1,
          ),
        ),
      ]);
      expect(
        (await store.monitoredBackups()).single.rowRevision,
        greaterThanOrEqualTo(2),
      );
      await db.close();
    },
  );

  test('newly created monitoring state is enabled by default', () async {
    final (db, store) = await build();
    expect((await store.state()).attemptMonitoringEnabled, isTrue);
    await db.close();
  });

  test('ETag is sent on the next poll and not-modified is advisory', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    var now = DateTime.now().toUtc();
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        totalAttempts: {},
        etag: 'cached',
      );
    final check = CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: remote,
      clock: () => now,
    );
    await check.execute();
    remote.response = RecoverBullAttemptsSnapshot(
      collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      totalAttempts: {},
      notModified: true,
    );
    now = now.add(const Duration(seconds: 61));
    await check.execute();
    expect(remote.lastEtag, 'cached');
    await db.close();
  });

  test(
    'window rollover adopts the new server baseline without an attack alert',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.recordStatus(id, _status(3));
      final digest = (await store.monitoredBackups()).single.digest;
      final next = window.add(const Duration(hours: 1));
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
          totalAttempts: {digest: 1},
          windowStartedAt: {digest: next},
        );
      expect(
        await CheckBackupAttemptMonitoringUsecase(
          store: store,
          remote: remote,
        ).execute(),
        isEmpty,
      );
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        1,
      );
      await db.close();
    },
  );

  test('service pressure is advisory', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        ),
        totalAttempts: {},
        serviceBusy: true,
      );
    expect(
      (await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
      ).execute()).single,
      isA<ServicePressureAlert>(),
    );
    await db.close();
  });

  test(
    'a rate-limited monitoring poll reports global service pressure',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final alerts = await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: _Remote()
          ..response = RecoverBullAttemptsSnapshot(
            collectionStartedAt: window,
            totalAttempts: const {},
            serviceBusy: true,
          ),
      ).execute();
      expect(alerts.single, isA<ServicePressureAlert>());
      await db.close();
    },
  );

  test('disable wipes monitored identifiers and resets generation', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final generation = (await store.state()).generation;
    await SetRecoverbullAttemptMonitoringEnabledUsecase(store).execute(false);
    expect(
      await IsRecoverbullAttemptMonitoringEnabledUsecase(store).execute(),
      isFalse,
    );
    expect(await store.monitoredBackups(), isEmpty);
    expect((await store.state()).generation, generation + 1);
    await db.close();
  });

  test('old server response without status does not count locally', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await RecordLocalAttemptUsecase(store).execute(backupIdHex: '00');
    expect(
      (await store.monitoredBackups())
          .single
          .expectedServerDistinctCandidateTotal,
      0,
    );
    await db.close();
  });

  test(
    'successful fetch without status adopts from the global snapshot',
    () async {
      final (db, store) = await build();
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {store.digestFor(id): 4},
          windowStartedAt: {store.digestFor(id): window},
        );

      await RecordLocalAttemptUsecase(
        store,
        remote: remote,
      ).execute(backupIdHex: _hex(id));

      final row = (await store.monitoredBackups()).single;
      expect(row.expectedServerDistinctCandidateTotal, 4);
      expect(row.currentWindow, attemptWindowIdentity(window));
      expect(row.lastWarningWindow, attemptWindowIdentity(window));
      await db.close();
    },
  );

  test('missing digest in the global snapshot is not adopted', () async {
    final (db, store) = await build();
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: window,
        totalAttempts: {store.digestFor(List<int>.filled(16, 9)): 4},
      );

    await RecordLocalAttemptUsecase(
      store,
      remote: remote,
    ).execute(backupIdHex: _hex(id));

    expect(await store.monitoredBackups(), isEmpty);
    await db.close();
  });

  test('opaque alert handle is not its digest or URL', () {
    final alert = public.RecoverBullAttemptAlert(
      public.RecoverBullAttemptAlertKind.suspiciousActivity,
    );
    expect(alert.kind, public.RecoverBullAttemptAlertKind.suspiciousActivity);
    expect(alert.toString(), isNot(contains('http')));
    expect(alert.toString(), isNot(contains('00')));
  });

  test(
    'polling remote failures do not escape the attempt monitoring check',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final remote = _ThrowingRemote();
      await expectLater(
        CheckBackupAttemptMonitoringUsecase(
          store: store,
          remote: remote,
        ).execute(),
        completes,
      );
      await db.close();
    },
  );

  test('first operation registers the backup with expected = 1', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await RecordLocalAttemptUsecase(
      store,
    ).execute(backupIdHex: _hex(id), attemptStatus: _status(1));
    expect(
      (await store.monitoredBackups())
          .single
          .expectedServerDistinctCandidateTotal,
      1,
    );
    await db.close();
  });

  test('server total exceeding this device count raises an alert', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final alert = await RecordLocalAttemptUsecase(
      store,
    ).execute(backupIdHex: _hex(id), attemptStatus: _status(3));
    expect(alert, isA<SuspiciousActivityAlert>());
    expect(alert!.expectedTotal, 1);
    await db.close();
  });

  test('a new window resets the local counter to 1', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await store.recordStatus(id, _status(3));
    await RecordLocalAttemptUsecase(store).execute(
      backupIdHex: _hex(id),
      attemptStatus: _status(1, at: window.add(const Duration(days: 1))),
    );
    final row = (await store.monitoredBackups()).single;
    expect(row.expectedServerDistinctCandidateTotal, 1);
    expect(
      row.currentWindow,
      attemptWindowIdentity(window.add(const Duration(days: 1))),
    );
    await db.close();
  });

  test(
    'own replays do not inflate the baseline, and a foreign candidate is still detected afterwards',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      for (var i = 0; i < 3; i++) {
        expect(
          await RecordLocalAttemptUsecase(
            store,
          ).execute(backupIdHex: _hex(id), attemptStatus: _status(1)),
          isNull,
        );
      }
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        1,
      );
      expect(
        await RecordLocalAttemptUsecase(
          store,
        ).execute(backupIdHex: _hex(id), attemptStatus: _status(3)),
        isA<SuspiciousActivityAlert>(),
      );
      await db.close();
    },
  );

  test('no monitored backups -> no check, no alerts', () async {
    final (db, store) = await build();
    final remote = _Remote();
    expect(
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
      ).execute(),
      isEmpty,
    );
    expect(remote.calls, 0);
    await db.close();
  });

  test('fresh last check -> skipped (no snapshot fetch)', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await store.applySnapshot(
      RecoverBullAttemptsSnapshot(
        collectionStartedAt: window,
        totalAttempts: {},
      ),
    );
    final remote = _Remote();
    expect(
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => window.add(const Duration(seconds: 1)),
      ).execute(),
      isEmpty,
    );
    expect(remote.calls, 0);
    await db.close();
  });

  test(
    'changed collection_started_at resets the baseline, no attack alarm',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.applySnapshot(
        RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {},
        ),
      );
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window.add(const Duration(hours: 1)),
          totalAttempts: {id: 9},
        );
      final alerts = await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => DateTime.now().toUtc().add(const Duration(minutes: 2)),
      ).execute();
      expect(alerts, isEmpty);
      expect(alerts.whereType<SuspiciousActivityAlert>(), isEmpty);
      await db.close();
    },
  );

  test('prolonged unavailability surfaces the soft warning once', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    await store.applySnapshot(
      RecoverBullAttemptsSnapshot(
        collectionStartedAt: window,
        totalAttempts: {},
      ),
    );
    final remote = _ThrowingRemote();
    final alerts = await CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: remote,
      clock: () => DateTime.now().toUtc().add(const Duration(days: 4)),
    ).execute();
    expect(alerts.single, isA<AttemptMonitoringUnavailableAlert>());
    await db.close();
  });

  test(
    'an exact attempt_status window and the hour-truncated snapshot window for the SAME window raise NO false alert',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.recordStatus(id, _status(1));
      final digest = (await store.monitoredBackups()).single.digest;
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 1},
          windowStartedAt: {digest: DateTime.utc(2026, 8, 5, 14)},
        );
      expect(
        await CheckBackupAttemptMonitoringUsecase(
          store: store,
          remote: remote,
        ).execute(),
        isEmpty,
      );
      await db.close();
    },
  );

  test(
    'a real extra attempt IS still detected across the precision boundary',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.recordStatus(id, _status(1));
      final digest = (await store.monitoredBackups()).single.digest;
      final remote = _Remote()
        ..response = RecoverBullAttemptsSnapshot(
          collectionStartedAt: window,
          totalAttempts: {digest: 3},
          windowStartedAt: {digest: DateTime.utc(2026, 8, 5, 14)},
        );
      final alerts = await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
      ).execute();
      expect(alerts.whereType<SuspiciousActivityAlert>(), hasLength(1));
      await db.close();
    },
  );

  test(
    'registering an already-monitored backup leaves the baseline alone',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      await store.recordStatus(id, _status(2));
      await store.registerBackup(id);
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        2,
      );
      await db.close();
    },
  );

  test('one attacker probe after a store is NOT masked', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final digest = (await store.monitoredBackups()).single.digest;
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: window,
        totalAttempts: {digest: 1},
        windowStartedAt: {digest: window},
      );
    expect(
      (await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
      ).execute()).whereType<SuspiciousActivityAlert>(),
      hasLength(1),
    );
    await db.close();
  });

  test(
    'a sustained /attempts flood escalates to the unavailability warning',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final remote = _ThrowingRemote();
      final clock = window.add(const Duration(days: 4));
      final usecase = CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: remote,
        clock: () => clock,
      );
      expect(await usecase.execute(), isEmpty);
      expect(await usecase.execute(), isEmpty);
      expect(
        (await usecase.execute()).single,
        isA<AttemptMonitoringUnavailableAlert>(),
      );
      await db.close();
    },
  );

  test('a single first-ever failure does not warn at all', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    expect(
      await CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: _ThrowingRemote(),
      ).execute(),
      isEmpty,
    );
    await db.close();
  });

  test('concurrent poll failures preserve every failure increment', () async {
    final (db, store) = await build();
    await store.registerBackup(id);

    await Future.wait([
      store.recordPollFailure(now: window),
      store.recordPollFailure(now: window),
    ]);

    expect((await store.state()).consecutiveFailures, 2);
    await db.close();
  });

  test(
    'repeated failures without any success warn with NO fabricated duration',
    () async {
      final (db, store) = await build();
      await store.registerBackup(id);
      final usecase = CheckBackupAttemptMonitoringUsecase(
        store: store,
        remote: _ThrowingRemote(),
        clock: () => window,
      );
      await usecase.execute();
      await usecase.execute();
      final alert =
          (await usecase.execute()).single as AttemptMonitoringUnavailableAlert;
      expect(alert.since, isNull);
      await db.close();
    },
  );

  test('the same window re-raises after a later check', () async {
    final (db, store) = await build();
    await store.registerBackup(id);
    final digest = (await store.monitoredBackups()).single.digest;
    final remote = _Remote()
      ..response = RecoverBullAttemptsSnapshot(
        collectionStartedAt: window,
        totalAttempts: {digest: 2},
        windowStartedAt: {digest: window},
      );
    var now = DateTime.now().toUtc();
    final check = CheckBackupAttemptMonitoringUsecase(
      store: store,
      remote: remote,
      clock: () => now,
    );
    expect(
      (await check.execute()).whereType<SuspiciousActivityAlert>(),
      hasLength(1),
    );
    now = now.add(const Duration(hours: 2));
    expect(
      (await check.execute()).whereType<SuspiciousActivityAlert>(),
      hasLength(1),
    );
    await db.close();
  });

  test('acknowledgement keeps alert handles ephemeral', () async {
    final alert = SuspiciousActivityAlert(
      backupIdHash: 'opaque',
      observedTotal: 1,
      expectedTotal: 0,
      windowStartedAt: DateTime.utc(2026),
    );
    await const AcknowledgeAttemptAlertUsecase().execute(alert);
    expect(alert.backupIdHash, isNot(contains('http')));
  });
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String _validVault(String seed) => jsonEncode({
  'version': 1,
  'created_at': 1780000000000,
  'id': (seed + seed).substring(0, 64),
  'salt': '000102030405060708090a0b0c0d0e0f',
  'ciphertext': base64Encode(List<int>.generate(64, (i) => i)),
  'path': "m/83696968'/0'/0'",
});

KeyServerAttemptStatus _status(int total, {DateTime? at}) =>
    KeyServerAttemptStatus(
      totalAttempts: total,
      failedAttempts: 0,
      remainingAttempts: 3 - total,
      windowStartedAt: at ?? DateTime.utc(2026, 8, 5, 14, 37, 22),
      previousAttemptAt: null,
      resetsAt: (at ?? DateTime.utc(2026, 8, 5, 14, 37, 22)).add(
        const Duration(days: 1),
      ),
    );

class _ThrowingRemote implements RecoverBullAttemptMonitoringRemotePort {
  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) => Future.error(StateError('offline'));
}
