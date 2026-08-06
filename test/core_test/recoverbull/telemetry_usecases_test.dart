import 'package:bb_mobile/core/recoverbull/data/repository/recoverbull_repository.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/key_server_telemetry.dart';
import 'package:bb_mobile/core/recoverbull/domain/entity/recoverbull_telemetry_alert.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/check_backup_telemetry_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/register_monitored_backup_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart' as recoverbull;

class _MockRepository extends Mock implements RecoverBullRepository {}

void main() {
  late _MockRepository repository;

  const serverUrl = 'http://example.onion';
  const backupIdHex =
      'bcb15f821479b4d5772bd0ca866c00ad5f926e3580720659cc80d39c9d09802a';
  final backupIdHash = recoverbull.attemptsIdHashFromHex(backupIdHex);

  setUpAll(() {
    registerFallbackValue(
      RecoverbullTelemetryServerRow(
        serverUrl: serverUrl,
        consecutiveFailures: 0,
      ),
    );
    registerFallbackValue(
      RecoverbullTelemetryBackupRow(
        serverUrl: serverUrl,
        backupIdHash: backupIdHash,
        expectedTotalAttempts: 0,
      ),
    );
    registerFallbackValue(<List<int>>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    repository = _MockRepository();
    when(
      () => repository.fetchUrl(),
    ).thenAnswer((_) async => Uri.parse(serverUrl));
  });

  RecoverbullTelemetryBackupRow backupRow({
    int expected = 0,
    int? window,
    int? lastWarning,
  }) {
    return RecoverbullTelemetryBackupRow(
      serverUrl: serverUrl,
      backupIdHash: backupIdHash,
      expectedTotalAttempts: expected,
      currentWindowStartedAt: window,
      lastWarningWindowStartedAt: lastWarning,
    );
  }

  KeyServerAttemptStatus status({
    required int total,
    required DateTime windowStartedAt,
  }) {
    return KeyServerAttemptStatus(
      totalAttempts: total,
      failedAttempts: 0,
      remainingAttempts: 3 - total,
      windowStartedAt: windowStartedAt,
      previousAttemptAt: null,
      resetsAt: windowStartedAt.add(const Duration(days: 1)),
    );
  }

  group('RecordLocalAttemptUsecase', () {
    test('first operation registers the backup with expected = 1', () async {
      when(
        () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
      ).thenAnswer((_) async => null);
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});

      final result = await RecordLocalAttemptUsecase(
        recoverBullRepository: repository,
      ).execute(backupIdHex: backupIdHex);

      expect(
        result,
        isA<Ok<SuspiciousActivityAlert?, RecoverBullCoreFailure>>(),
      );
      final alert =
          (result as Ok<SuspiciousActivityAlert?, RecoverBullCoreFailure>)
              .value;
      expect(alert, isNull);

      final captured = verify(
        () => repository.upsertTelemetryBackup(captureAny()),
      ).captured;
      final row = captured.single as RecoverbullTelemetryBackupRow;
      expect(row.expectedTotalAttempts, 1);
    });

    test('server total exceeding this device count raises an alert', () async {
      // the attacker probed twice before the user's first fetch
      when(
        () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
      ).thenAnswer((_) async => null);
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});

      final window = DateTime.utc(2026, 8, 5, 12);
      final result =
          await RecordLocalAttemptUsecase(
            recoverBullRepository: repository,
          ).execute(
            backupIdHex: backupIdHex,
            attemptStatus: status(total: 3, windowStartedAt: window),
          );

      final alert =
          (result as Ok<SuspiciousActivityAlert?, RecoverBullCoreFailure>)
              .value;
      expect(alert, isNotNull);
      expect(alert!.observedTotal, 3);
      expect(alert.expectedTotal, 1);
    });

    test('a new window resets the local counter to 1', () async {
      final oldWindow = DateTime.utc(2026, 8, 4, 12);
      final newWindow = DateTime.utc(2026, 8, 5, 12);
      when(
        () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
      ).thenAnswer(
        (_) async => backupRow(
          expected: 3,
          window: oldWindow.millisecondsSinceEpoch ~/ 1000,
        ),
      );
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});

      final result =
          await RecordLocalAttemptUsecase(
            recoverBullRepository: repository,
          ).execute(
            backupIdHex: backupIdHex,
            attemptStatus: status(total: 1, windowStartedAt: newWindow),
          );

      final alert =
          (result as Ok<SuspiciousActivityAlert?, RecoverBullCoreFailure>)
              .value;
      expect(alert, isNull);

      final captured = verify(
        () => repository.upsertTelemetryBackup(captureAny()),
      ).captured;
      final row = captured.single as RecoverbullTelemetryBackupRow;
      expect(row.expectedTotalAttempts, 1);
      expect(
        row.currentWindowStartedAt,
        newWindow.millisecondsSinceEpoch ~/ 1000,
      );
    });
  });

  group('CheckBackupTelemetryUsecase', () {
    CheckBackupTelemetryUsecase buildUsecase() =>
        CheckBackupTelemetryUsecase(recoverBullRepository: repository);

    void stubNoBackups() {
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => []);
    }

    void stubServerState(RecoverbullTelemetryServerRow? row) {
      when(
        () => repository.fetchTelemetryServerState(serverUrl),
      ).thenAnswer((_) async => row);
    }

    void stubUpserts() {
      when(
        () => repository.upsertTelemetryServerState(any()),
      ).thenAnswer((_) async {});
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});
    }

    test('no monitored backups -> no check, no alerts', () async {
      stubNoBackups();

      final result = await buildUsecase().execute();

      expect(
        (result as Ok<List<RecoverbullTelemetryAlert>, RecoverBullCoreFailure>)
            .value,
        isEmpty,
      );
      verifyNever(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      );
    });

    test('fresh last check -> skipped (no snapshot fetch)', () async {
      final now = DateTime.now();
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [backupRow(expected: 1)]);
      stubServerState(
        RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          lastSuccessfulCheckAt: now.millisecondsSinceEpoch ~/ 1000,
          consecutiveFailures: 0,
        ),
      );

      final result = await buildUsecase().execute();

      expect(
        (result as Ok<List<RecoverbullTelemetryAlert>, RecoverBullCoreFailure>)
            .value,
        isEmpty,
      );
      verifyNever(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      );
    });

    test(
      'snapshot entry exceeding the device count warns once per window',
      () async {
        final window = DateTime.utc(2026, 8, 5, 12);
        final windowEpoch = window.millisecondsSinceEpoch ~/ 1000;
        when(() => repository.fetchTelemetryBackups(serverUrl)).thenAnswer(
          (_) async => [backupRow(expected: 1, window: windowEpoch)],
        );
        stubServerState(
          RecoverbullTelemetryServerRow(
            serverUrl: serverUrl,
            consecutiveFailures: 0,
          ),
        );
        stubUpserts();
        when(() => repository.fetchServerInfo()).thenAnswer(
          (_) async => const Ok(
            KeyServerInfo(
              collectionStartedAt: null,
              maxAttemptIdentifiers: 100000,
            ),
          ),
        );
        when(
          () => repository.fetchTelemetrySnapshot(
            etag: any(named: 'etag'),
            backupIdHashes: any(named: 'backupIdHashes'),
          ),
        ).thenAnswer(
          (_) async => Ok(
            TelemetrySnapshotModified(
              etag: 'new-etag',
              maxAgeSeconds: 60,
              collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
              totalEntries: 1,
              matchingEntries: [
                KeyServerAttemptEntry(
                  idHash: backupIdHash,
                  totalAttempts: 3,
                  failedAttempts: 2,
                  windowStartedAt: window,
                  lastAttemptAt: window,
                ),
              ],
            ),
          ),
        );

        final result = await buildUsecase().execute();

        final alerts =
            (result
                    as Ok<
                      List<RecoverbullTelemetryAlert>,
                      RecoverBullCoreFailure
                    >)
                .value;
        expect(alerts, hasLength(1));
        expect(alerts.single, isA<SuspiciousActivityAlert>());
        final alert = alerts.single as SuspiciousActivityAlert;
        expect(alert.observedTotal, 3);
        expect(alert.expectedTotal, 1);
      },
    );

    test('matching device count stays silent', () async {
      final window = DateTime.utc(2026, 8, 5, 12);
      final windowEpoch = window.millisecondsSinceEpoch ~/ 1000;
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [backupRow(expected: 3, window: windowEpoch)]);
      stubServerState(
        RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          consecutiveFailures: 0,
        ),
      );
      stubUpserts();
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          TelemetrySnapshotModified(
            etag: 'new-etag',
            maxAgeSeconds: 60,
            collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
            totalEntries: 1,
            matchingEntries: [
              KeyServerAttemptEntry(
                idHash: backupIdHash,
                totalAttempts: 3,
                failedAttempts: 0,
                windowStartedAt: window,
                lastAttemptAt: window,
              ),
            ],
          ),
        ),
      );

      final result = await buildUsecase().execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(alerts.whereType<SuspiciousActivityAlert>(), isEmpty);
    });

    test(
      'changed collection_started_at resets the baseline, no attack alarm',
      () async {
        final wipedAt = DateTime.utc(2026, 8, 5, 10);
        when(
          () => repository.fetchTelemetryBackups(serverUrl),
        ).thenAnswer((_) async => [backupRow(expected: 3, window: 123)]);
        stubServerState(
          RecoverbullTelemetryServerRow(
            serverUrl: serverUrl,
            collectionStartedAt: 999, // stale marker
            consecutiveFailures: 0,
          ),
        );
        stubUpserts();
        when(() => repository.fetchServerInfo()).thenAnswer(
          (_) async => Ok(
            KeyServerInfo(
              collectionStartedAt: wipedAt,
              maxAttemptIdentifiers: 100000,
            ),
          ),
        );
        when(
          () => repository.fetchTelemetrySnapshot(
            etag: any(named: 'etag'),
            backupIdHashes: any(named: 'backupIdHashes'),
          ),
        ).thenAnswer((_) async => const Ok(TelemetrySnapshotNotModified()));

        final result = await buildUsecase().execute();

        final alerts =
            (result
                    as Ok<
                      List<RecoverbullTelemetryAlert>,
                      RecoverBullCoreFailure
                    >)
                .value;
        expect(alerts, hasLength(1));
        expect(alerts.single, isA<CountersWipedAlert>());
        expect(alerts.single, isNot(isA<SuspiciousActivityAlert>()));

        // the baseline was reset to zero
        final captured = verify(
          () => repository.upsertTelemetryBackup(captureAny()),
        ).captured;
        final row = captured.single as RecoverbullTelemetryBackupRow;
        expect(row.expectedTotalAttempts, 0);
        expect(row.currentWindowStartedAt, isNull);
      },
    );

    test('global 429 surfaces service pressure, not an attack', () async {
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [backupRow(expected: 1)]);
      stubServerState(
        RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          consecutiveFailures: 0,
        ),
      );
      stubUpserts();
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer(
        (_) async => Err(const KeyServerOverloadedFailure('global 429')),
      );

      final result = await buildUsecase().execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(alerts, hasLength(1));
      expect(alerts.single, isA<ServicePressureAlert>());
      expect(
        (alerts.single as ServicePressureAlert).kind,
        ServicePressureKind.global429,
      );
    });

    test('prolonged unavailability surfaces the soft warning once', () async {
      final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [backupRow(expected: 1)]);
      stubServerState(
        RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          lastSuccessfulCheckAt: fourDaysAgo.millisecondsSinceEpoch ~/ 1000,
          consecutiveFailures: 2,
        ),
      );
      stubUpserts();
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer((_) async => Err(const KeyServerUnavailableFailure('down')));

      final result = await buildUsecase().execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(alerts, hasLength(1));
      expect(alerts.single, isA<TelemetryUnavailableAlert>());
    });
  });

  // -------------------------------------------------------------------------
  // Adversarial: the two endpoints serve the SAME window at DIFFERENT
  // precisions. These tests feed asymmetric data on purpose — the earlier
  // tests fed identical DateTimes to both sides, which is exactly why they
  // could not catch the mismatch that raised a false alert on every recovery.
  // -------------------------------------------------------------------------

  group('window precision asymmetry (regression)', () {
    test('an exact attempt_status window and the hour-truncated snapshot '
        'window for the SAME window raise NO false alert', () async {
      // 14:37:22 exact from attempt_status, 14:00:00 truncated in the snapshot
      final exactWindow = DateTime.utc(2026, 8, 5, 14, 37, 22);
      final truncatedWindow = DateTime.utc(2026, 8, 5, 14);

      // the user's own fetch records the exact window
      when(
        () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
      ).thenAnswer((_) async => null);
      final captured = <RecoverbullTelemetryBackupRow>[];
      when(() => repository.upsertTelemetryBackup(any())).thenAnswer((
        invocation,
      ) async {
        captured.add(
          invocation.positionalArguments.first as RecoverbullTelemetryBackupRow,
        );
      });

      await RecordLocalAttemptUsecase(
        recoverBullRepository: repository,
      ).execute(
        backupIdHex: backupIdHex,
        attemptStatus: status(total: 1, windowStartedAt: exactWindow),
      );
      final stored = captured.single;
      expect(stored.expectedTotalAttempts, 1);

      // the cold-launch check sees the same window, hour-truncated
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [stored]);
      when(() => repository.fetchTelemetryServerState(serverUrl)).thenAnswer(
        (_) async => RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          consecutiveFailures: 0,
        ),
      );
      when(
        () => repository.upsertTelemetryServerState(any()),
      ).thenAnswer((_) async {});
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          TelemetrySnapshotModified(
            etag: 'etag',
            maxAgeSeconds: 60,
            collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
            totalEntries: 1,
            matchingEntries: [
              KeyServerAttemptEntry(
                idHash: backupIdHash,
                totalAttempts: 1, // the user's own fetch, nothing else
                failedAttempts: 0,
                windowStartedAt: truncatedWindow,
                lastAttemptAt: truncatedWindow,
              ),
            ],
          ),
        ),
      );

      final result = await CheckBackupTelemetryUsecase(
        recoverBullRepository: repository,
      ).execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(
        alerts.whereType<SuspiciousActivityAlert>(),
        isEmpty,
        reason:
            'the same window at two precisions must not look like unknown activity',
      );
    });

    test('a real extra attempt IS still detected across the precision '
        'boundary', () async {
      final exactWindow = DateTime.utc(2026, 8, 5, 14, 37, 22);
      final truncatedWindow = DateTime.utc(2026, 8, 5, 14);
      final windowIdentity = telemetryWindowIdentity(exactWindow);

      when(() => repository.fetchTelemetryBackups(serverUrl)).thenAnswer(
        (_) async => [backupRow(expected: 1, window: windowIdentity)],
      );
      when(() => repository.fetchTelemetryServerState(serverUrl)).thenAnswer(
        (_) async => RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          consecutiveFailures: 0,
        ),
      );
      when(
        () => repository.upsertTelemetryServerState(any()),
      ).thenAnswer((_) async {});
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          TelemetrySnapshotModified(
            etag: 'etag',
            maxAgeSeconds: 60,
            collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
            totalEntries: 1,
            matchingEntries: [
              KeyServerAttemptEntry(
                idHash: backupIdHash,
                totalAttempts: 3, // two probes on top of the user's fetch
                failedAttempts: 2,
                windowStartedAt: truncatedWindow,
                lastAttemptAt: truncatedWindow,
              ),
            ],
          ),
        ),
      );

      final result = await CheckBackupTelemetryUsecase(
        recoverBullRepository: repository,
      ).execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(alerts.whereType<SuspiciousActivityAlert>(), hasLength(1));
      final alert = alerts.whereType<SuspiciousActivityAlert>().single;
      expect(alert.observedTotal, 3);
      expect(
        alert.expectedTotal,
        1,
        reason: 'the local count must survive the compare',
      );
    });
  });

  group('store is not counted (regression)', () {
    test(
      'registering a monitored backup does not increment the counter',
      () async {
        when(
          () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
        ).thenAnswer((_) async => null);
        final captured = <RecoverbullTelemetryBackupRow>[];
        when(() => repository.upsertTelemetryBackup(any())).thenAnswer((
          invocation,
        ) async {
          captured.add(
            invocation.positionalArguments.first
                as RecoverbullTelemetryBackupRow,
          );
        });

        await RegisterMonitoredBackupUsecase(
          recoverBullRepository: repository,
        ).execute(backupIdHex: backupIdHex);

        expect(
          captured.single.expectedTotalAttempts,
          0,
          reason: 'a store must not consume budget the server never counted',
        );
      },
    );

    test(
      'registering an already-monitored backup leaves the baseline alone',
      () async {
        when(
          () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
        ).thenAnswer((_) async => backupRow(expected: 2, window: 123));
        when(
          () => repository.upsertTelemetryBackup(any()),
        ).thenAnswer((_) async {});

        await RegisterMonitoredBackupUsecase(
          recoverBullRepository: repository,
        ).execute(backupIdHex: backupIdHex);

        verifyNever(() => repository.upsertTelemetryBackup(any()));
      },
    );

    test('one attacker probe after a store is NOT masked', () async {
      // the store registered the backup with expected = 0
      final window = DateTime.utc(2026, 8, 5, 14);
      when(() => repository.fetchTelemetryBackups(serverUrl)).thenAnswer(
        (_) async => [
          backupRow(expected: 0, window: telemetryWindowIdentity(window)),
        ],
      );
      when(() => repository.fetchTelemetryServerState(serverUrl)).thenAnswer(
        (_) async => RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          consecutiveFailures: 0,
        ),
      );
      when(
        () => repository.upsertTelemetryServerState(any()),
      ).thenAnswer((_) async {});
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          TelemetrySnapshotModified(
            etag: 'etag',
            maxAgeSeconds: 60,
            collectionStartedAt: DateTime.utc(2026, 8, 5, 9),
            totalEntries: 1,
            matchingEntries: [
              KeyServerAttemptEntry(
                idHash: backupIdHash,
                totalAttempts: 1, // a single attacker probe
                failedAttempts: 1,
                windowStartedAt: window,
                lastAttemptAt: window,
              ),
            ],
          ),
        ),
      );

      final result = await CheckBackupTelemetryUsecase(
        recoverBullRepository: repository,
      ).execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(
        alerts.whereType<SuspiciousActivityAlert>(),
        hasLength(1),
        reason: 'a store must not inflate the baseline and hide a probe',
      );
    });
  });

  group('suppression escalation and honest copy (regression)', () {
    void stubBaseline({int? lastSuccess, int failures = 0}) {
      when(
        () => repository.fetchTelemetryBackups(serverUrl),
      ).thenAnswer((_) async => [backupRow(expected: 1)]);
      when(() => repository.fetchTelemetryServerState(serverUrl)).thenAnswer(
        (_) async => RecoverbullTelemetryServerRow(
          serverUrl: serverUrl,
          lastSuccessfulCheckAt: lastSuccess,
          consecutiveFailures: failures,
        ),
      );
      when(
        () => repository.upsertTelemetryServerState(any()),
      ).thenAnswer((_) async {});
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});
      when(() => repository.fetchServerInfo()).thenAnswer(
        (_) async => const Ok(
          KeyServerInfo(
            collectionStartedAt: null,
            maxAttemptIdentifiers: 100000,
          ),
        ),
      );
    }

    test(
      'a sustained /attempts flood escalates to the unavailability warning',
      () async {
        // stale success plus a global 429: suppression must not stay a mild
        // "service issue" notice forever
        final fourDaysAgo = DateTime.now().subtract(const Duration(days: 4));
        stubBaseline(
          lastSuccess: fourDaysAgo.millisecondsSinceEpoch ~/ 1000,
          failures: 5,
        );
        when(
          () => repository.fetchTelemetrySnapshot(
            etag: any(named: 'etag'),
            backupIdHashes: any(named: 'backupIdHashes'),
          ),
        ).thenAnswer(
          (_) async => Err(const KeyServerOverloadedFailure('flood')),
        );

        final result = await CheckBackupTelemetryUsecase(
          recoverBullRepository: repository,
        ).execute();

        final alerts =
            (result
                    as Ok<
                      List<RecoverbullTelemetryAlert>,
                      RecoverBullCoreFailure
                    >)
                .value;
        expect(alerts.whereType<ServicePressureAlert>(), hasLength(1));
        expect(
          alerts.whereType<TelemetryUnavailableAlert>(),
          hasLength(1),
          reason: 'a flood must eventually escalate, not stay a service notice',
        );
      },
    );

    test('a single first-ever failure does not warn at all', () async {
      stubBaseline(lastSuccess: null, failures: 0);
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer((_) async => Err(const KeyServerUnavailableFailure('tor')));

      final result = await CheckBackupTelemetryUsecase(
        recoverBullRepository: repository,
      ).execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      expect(
        alerts.whereType<TelemetryUnavailableAlert>(),
        isEmpty,
        reason: 'a transient first failure must not claim an outage',
      );
    });

    test('repeated failures without any success warn with NO fabricated '
        'duration', () async {
      stubBaseline(
        lastSuccess: null,
        failures: CheckBackupTelemetryUsecase.minFailuresWithoutSuccess - 1,
      );
      when(
        () => repository.fetchTelemetrySnapshot(
          etag: any(named: 'etag'),
          backupIdHashes: any(named: 'backupIdHashes'),
        ),
      ).thenAnswer((_) async => Err(const KeyServerUnavailableFailure('tor')));

      final result = await CheckBackupTelemetryUsecase(
        recoverBullRepository: repository,
      ).execute();

      final alerts =
          (result
                  as Ok<
                    List<RecoverbullTelemetryAlert>,
                    RecoverBullCoreFailure
                  >)
              .value;
      final alert = alerts.whereType<TelemetryUnavailableAlert>().single;
      expect(
        alert.since,
        isNull,
        reason: 'never having succeeded means there is no duration to report',
      );
    });
  });

  group('alert dedup per window (regression)', () {
    test('the same window does not re-raise on a second recovery', () async {
      final window = DateTime.utc(2026, 8, 5, 14, 37, 22);
      final identity = telemetryWindowIdentity(window);

      // a warning was already raised for this window
      when(
        () => repository.fetchTelemetryBackup(serverUrl, backupIdHash),
      ).thenAnswer(
        (_) async =>
            backupRow(expected: 1, window: identity, lastWarning: identity),
      );
      when(
        () => repository.upsertTelemetryBackup(any()),
      ).thenAnswer((_) async {});

      final result =
          await RecordLocalAttemptUsecase(
            recoverBullRepository: repository,
          ).execute(
            backupIdHex: backupIdHex,
            attemptStatus: status(total: 5, windowStartedAt: window),
          );

      final alert =
          (result as Ok<SuspiciousActivityAlert?, RecoverBullCoreFailure>)
              .value;
      expect(
        alert,
        isNull,
        reason: 'one alert per window: an acknowledged window must stay quiet',
      );
    });
  });
}
