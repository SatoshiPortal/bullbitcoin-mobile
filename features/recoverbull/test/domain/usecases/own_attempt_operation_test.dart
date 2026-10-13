import 'package:bull_recoverbull/src/domain/recoverbull_attempt_alert_port.dart';
import 'dart:async';
import 'dart:io';

import 'package:bull_recoverbull/src/data/recoverbull_attempt_monitoring_store.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/database/recoverbull_database.dart';
import 'package:bull_recoverbull/src/domain/entities/attempt_alert.dart';
import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/check_backup_attempt_monitoring_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/ensure_recoverbull_tor_session_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_vault_key_from_server_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/record_local_attempt_usecase.dart';
import 'package:bull_recoverbull/src/public/recoverbull.dart';
import 'package:bull_tor/tor.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';
import '../../support/monitoring_repository.dart';

class _KeyRepository extends Mock implements RecoverBullRepository {}

class _Session extends Mock implements EnsureRecoverBullTorSessionUsecase {}

final class _Remote implements RecoverBullAttemptMonitoringRemotePort {
  final Future<RecoverBullAttemptsSnapshot?> Function() response;
  const _Remote(this.response);
  @override
  Future<RecoverBullAttemptsSnapshot?> poll({
    required String? etag,
    required List<String> backupDigests,
  }) => response();
}

void main() {
  late RecoverBullDatabase db;
  late RecoverBullAttemptMonitoringStore store;
  late RecoverBullAttemptMonitoringRepository repository;
  final window = DateTime.utc(2026, 10, 13, 9);
  final collection = DateTime.utc(2026, 10, 1);
  const id = [1, 2, 3];

  RecoverBullAttemptsSnapshot snapshot(
    int count, {
    DateTime? counterWindow,
    bool busy = false,
  }) => RecoverBullAttemptsSnapshot(
    collectionStartedAt: collection,
    totalAttempts: {store.digestFor(id): count},
    windowStartedAt: {store.digestFor(id): counterWindow ?? window},
    serviceBusy: busy,
    etag: 'count-$count',
  );
  KeyServerAttemptStatus status(int count, {DateTime? counterWindow}) =>
      KeyServerAttemptStatus(
        totalAttempts: count,
        failedAttempts: count,
        remainingAttempts: 3 - count,
        windowStartedAt: counterWindow ?? window,
        previousAttemptAt: null,
        resetsAt: (counterWindow ?? window).add(const Duration(hours: 1)),
      );
  RecordLocalAttemptUsecase recorder({
    RecoverBullAttemptMonitoringRemotePort? remote,
  }) => RecordLocalAttemptUsecase(
    repository,
    remote: remote,
    clock: () => window,
  );
  Future<List<AttemptAlert>> check(
    RecoverBullAttemptMonitoringRemotePort remote,
  ) => CheckBackupAttemptMonitoringUsecase(
    store: repository,
    remote: remote,
    clock: () => window,
  ).execute(forceRefresh: true).requireOk();

  setUp(() async {
    db = RecoverBullDatabase.forTesting(NativeDatabase.memory());
    await db.ensureState();
    store = RecoverBullAttemptMonitoringStore(db);
    repository = monitoringRepository(store);
    await store.registerBackup(id);
  });
  tearDown(() => db.close());

  test(
    'a wrong-password HTTP401 is counted as this users own distinct candidate',
    () async {
      final identifier = List<int>.generate(32, (i) => i);
      final vault = EncryptedVault(
        id: identifier.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        salt: List.filled(16, '00').join(),
        ciphertext: List.filled(64, 0),
        createdAt: window,
      );
      await store.registerBackup(identifier);
      RecoverBullAttemptsSnapshot telemetry(int count) =>
          RecoverBullAttemptsSnapshot(
            collectionStartedAt: collection,
            totalAttempts: {store.digestFor(identifier): count},
            windowStartedAt: {store.digestFor(identifier): window},
          );
      final record = recorder(remote: _Remote(() async => telemetry(1)));
      final keyRepository = _KeyRepository();
      final serverReply =
          Completer<Result<VaultKeyFetchResult, RecoverBullFailure>>();
      final entered = Completer<void>();
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final route = RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
          evidence: TorReadinessEvidence.embeddedBootstrap,
          transport: TorTransport.direct,
        ),
        () async {},
        client,
      );
      when(
        () => keyRepository.fetchVaultKeyWithStatus(
          vault.id,
          'wrong-password',
          vault.salt,
          route,
        ),
      ).thenAnswer((_) {
        if (!entered.isCompleted) entered.complete();
        return serverReply.future;
      });
      final alerts = _Alerts();
      final fetch = FetchVaultKeyFromServerUsecase(
        repository: keyRepository,
        ensureTor: _Session(),
        recordAttempt: record,
        alertPort: alerts,
        log: const TestLogSink(),
      );
      final result = fetch.execute(
        vault: vault,
        password: 'wrong-password',
        route: route,
      );
      await entered.future;
      expect(await check(_Remote(() async => telemetry(1))), isEmpty);
      serverReply.complete(const Err(KeyServerInvalidCredentialsFailure()));
      expect(await result, isA<Err<String, RecoverBullFailure>>());
      for (var turn = 0; turn < 20; turn++) {
        await pumpEventQueue(times: 1);
        final rows = await store.monitoredBackups();
        if (rows.any((row) => row.expectedServerDistinctCandidateTotal == 1)) {
          break;
        }
      }
      expect(alerts.values, isEmpty);
      expect(
        (await store.monitoredBackups()).where(
          (row) => row.expectedServerDistinctCandidateTotal == 1,
        ),
        hasLength(1),
      );
    },
  );

  test(
    'a poll sees an own candidate before HTTP completion without an alarm',
    () async {
      final record = recorder();
      final operation = (await record
          .beginOwnOperation(
            backupIdHex: '010203',
            password: 'fixture-password',
          )
          .requireOk())!;
      expect(await check(_Remote(() async => snapshot(1))), isEmpty);
      expect((await store.state()).etag, isNull);
      expect(
        await record
            .completeOwnOperation(
              operation: operation,
              counted: true,
              status: status(1),
            )
            .requireOk(),
        isNull,
      );
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        1,
      );
    },
  );

  test(
    'an own operation begins and finishes during a poll and real excess is retried',
    () async {
      final record = recorder();
      expect(
        await check(
          _Remote(() async {
            final operation = (await record
                .beginOwnOperation(
                  backupIdHex: '010203',
                  password: 'fixture-password',
                )
                .requireOk())!;
            await record
                .completeOwnOperation(
                  operation: operation,
                  counted: true,
                  status: status(1),
                )
                .requireOk();
            return snapshot(2);
          }),
        ),
        isEmpty,
      );
      expect((await store.state()).etag, isNull);
      expect(
        (await check(_Remote(() async => snapshot(2)))).single,
        isA<SuspiciousActivityAlert>(),
      );
    },
  );

  test(
    'unknown 401 credits one distinct own candidate and repeats cannot hide an attack',
    () async {
      final record = recorder();
      for (var attempt = 0; attempt < 2; attempt++) {
        final operation = (await record
            .beginOwnOperation(
              backupIdHex: '010203',
              password: 'same-wrong-password',
            )
            .requireOk())!;
        expect(
          await record
              .completeOwnOperation(operation: operation, counted: true)
              .requireOk(),
          isNull,
        );
      }
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        1,
      );
      final alert =
          (await check(_Remote(() async => snapshot(2)))).single
              as SuspiciousActivityAlert;
      expect(alert.expectedTotal, 1);
      expect(alert.observedTotal, 2);
    },
  );

  test(
    '401 telemetry reports real excess instead of adopting its whole counter',
    () async {
      final record = recorder(remote: _Remote(() async => snapshot(2)));
      final operation = (await record
          .beginOwnOperation(backupIdHex: '010203', password: 'wrong-password')
          .requireOk())!;
      final alert = await record
          .completeOwnOperation(operation: operation, counted: true)
          .requireOk();
      expect(alert, isA<SuspiciousActivityAlert>());
      expect(alert!.expectedTotal, 1);
      expect(alert.observedTotal, 2);
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        1,
      );
    },
  );

  test(
    'concurrent own operations do not blame one another and retain real excess',
    () async {
      final record = recorder();
      final first = (await record
          .beginOwnOperation(backupIdHex: '010203', password: 'first')
          .requireOk())!;
      final second = (await record
          .beginOwnOperation(backupIdHex: '010203', password: 'second')
          .requireOk())!;
      expect(
        await record
            .completeOwnOperation(
              operation: first,
              counted: true,
              status: status(3),
            )
            .requireOk(),
        isNull,
      );
      final alert = await record
          .completeOwnOperation(
            operation: second,
            counted: true,
            status: status(3),
          )
          .requireOk();
      expect(alert!.expectedTotal, 2);
      expect(alert.observedTotal, 3);
    },
  );

  test(
    'a capped fingerprint ledger never grants repeated unproven credit',
    () async {
      final record = recorder();
      for (var count = 1; count <= 32; count++) {
        final operation = (await record
            .beginOwnOperation(
              backupIdHex: '010203',
              password: 'candidate-$count',
            )
            .requireOk())!;
        expect(
          await record
              .completeOwnOperation(
                operation: operation,
                counted: true,
                status: status(count),
              )
              .requireOk(),
          isNull,
        );
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        final operation = (await record
            .beginOwnOperation(
              backupIdHex: '010203',
              password: 'candidate-beyond-cap',
            )
            .requireOk())!;
        final alert = await record
            .completeOwnOperation(
              operation: operation,
              counted: true,
              status: status(34),
            )
            .requireOk();
        expect(alert!.expectedTotal, 32);
        expect(alert.observedTotal, 34);
      }
      expect(
        (await store.monitoredBackups())
            .single
            .expectedServerDistinctCandidateTotal,
        32,
      );
    },
  );

  test(
    'an older inline completion cannot regress a newer window baseline',
    () async {
      final record = recorder();
      final old = (await record
          .beginOwnOperation(
            backupIdHex: '010203',
            password: 'old-window-candidate',
          )
          .requireOk())!;
      final newer = (await record
          .beginOwnOperation(
            backupIdHex: '010203',
            password: 'new-window-candidate',
          )
          .requireOk())!;
      final next = window.add(const Duration(hours: 1));
      expect(
        await record
            .completeOwnOperation(
              operation: newer,
              counted: true,
              status: status(1, counterWindow: next),
            )
            .requireOk(),
        isNull,
      );
      final before = (await store.monitoredBackups()).single;
      expect(
        await record
            .completeOwnOperation(
              operation: old,
              counted: true,
              status: status(7),
            )
            .requireOk(),
        isNull,
      );
      final after = (await store.monitoredBackups()).single;
      expect(after.currentWindow, attemptWindowIdentity(next));
      expect(
        after.expectedServerDistinctCandidateTotal,
        before.expectedServerDistinctCandidateTotal,
      );
      expect(after.rowRevision, before.rowRevision);
      final alert =
          (await check(
                _Remote(() async => snapshot(2, counterWindow: next)),
              )).single
              as SuspiciousActivityAlert;
      expect(alert.expectedTotal, 1);
      expect(alert.observedTotal, 2);
    },
  );

  test(
    'a conflicting newer window cannot be compared to old window counts',
    () async {
      await store.recordOwnAttempt(id, serverTotalAttempts: 1, window: window);
      final next = window.add(const Duration(hours: 1));
      expect(
        await check(
          _Remote(() async {
            await store.recordOwnAttempt(
              id,
              serverTotalAttempts: 0,
              window: next,
            );
            return snapshot(9);
          }),
        ),
        isEmpty,
      );
      final alert =
          (await check(
                _Remote(() async => snapshot(1, counterWindow: next)),
              )).single
              as SuspiciousActivityAlert;
      expect(alert.expectedTotal, 0);
      expect(alert.windowStartedAt, next);
    },
  );

  for (final failure in ['503', 'network']) {
    for (final change in ['disable', 'reset', 'server']) {
      test('late $failure after $change cannot mutate or alert', () async {
        final alerts = await check(
          _Remote(() async {
            switch (change) {
              case 'disable':
                await store.setEnabled(false);
              case 'reset':
                await store.reset();
              case 'server':
                await RecoverbullSettingsDatasource(
                  database: db,
                ).store(Uri.parse('http://new-server.onion'));
            }
            if (failure == 'network') throw Exception('transport fixture');
            return snapshot(0, busy: true);
          }),
        );
        expect(alerts, isEmpty);
        expect((await store.state()).consecutiveFailures, 0);
        expect((await store.state()).lastUnavailabilityWarningAt, isNull);
      });
    }
  }

  test(
    'reset forgets unsupported capability and old failure cooldown',
    () async {
      await store.recordAttemptsUnsupported(
        until: window.add(const Duration(days: 1)),
      );
      await store.recordPollFailure(now: window);
      await store.reset();
      expect((await store.state()).attemptsUnsupportedUntil, isNull);
      expect((await store.state()).consecutiveFailures, 0);
    },
  );

  test(
    'successful monitoring removes a stale unavailable visible alert',
    () async {
      RecoverBullAttemptsSnapshot? response;
      final monitoring = RecoverBullAttemptMonitoring(
        repository,
        enabled: true,
        poll: ({required etag, required backupDigests}) async => response,
      );
      for (var attempt = 0; attempt < 3; attempt++) {
        await monitoring.checkOnForeground();
      }
      expect(
        (await monitoring.alerts.first).single.kind,
        RecoverBullAttemptAlertKind.unavailable,
      );
      response = snapshot(0);
      expect(await monitoring.checkOnForeground(), isEmpty);
      expect(await monitoring.alerts.first, isEmpty);
    },
  );

  test(
    'inline and snapshot alerts have the same hourly window identity',
    () async {
      final digest = store
          .digestFor(id)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      final monitoring = RecoverBullAttemptMonitoring(
        repository,
        enabled: true,
        poll: ({required etag, required backupDigests}) async => snapshot(2),
      );
      await store.recordOwnAttempt(id, serverTotalAttempts: 1, window: window);
      monitoring.publish(
        SuspiciousActivityAlert(
          backupIdHash: digest,
          observedTotal: 2,
          expectedTotal: 1,
          windowStartedAt: window.add(const Duration(minutes: 37)),
        ),
      );
      await monitoring.checkOnForeground();
      expect(await monitoring.alerts.first, hasLength(1));
    },
  );

  test(
    'temporary monitoring refuses activation without writing the preference',
    () async {
      await store.setEnabled(false);
      final monitoring = await RecoverBullAttemptMonitoring.open(
        repository,
        enabled: true,
        enabledAllowed: false,
      );
      expect(monitoring.enabled, isFalse);
      expect((await monitoring.status()).enabledAllowed, isFalse);
      expect(
        await monitoring.setEnabledResult(true),
        isA<Err<RecoverBullMonitoringStatus, RecoverBullFailure>>(),
      );
      expect((await store.state()).attemptMonitoringEnabled, isFalse);
    },
  );

  test(
    'teardown cancels an advisory completion before the database closes',
    () async {
      final monitoring = RecoverBullAttemptMonitoring(
        repository,
        enabled: true,
      );
      final record = recorder();
      final operation = (await record
          .beginOwnOperation(
            backupIdHex: '010203',
            password: 'fixture-password',
          )
          .requireOk())!;
      await monitoring.close();
      await db.close();
      expect(
        await record
            .completeOwnOperation(
              operation: operation,
              counted: true,
              status: status(1),
            )
            .requireOk(),
        isNull,
      );
    },
  );
}

final class _Alerts implements RecoverBullAttemptAlertPort {
  final List<AttemptAlert> values = [];
  @override
  void publish(AttemptAlert alert) => values.add(alert);
}
