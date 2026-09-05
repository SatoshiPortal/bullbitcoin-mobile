import 'dart:async';
import 'dart:io';
import '../support/log_sink.dart';

import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:recoverbull/recoverbull.dart';

final class _Settings extends Mock implements RecoverbullSettingsDatasource {}

final class _Client implements HttpClient {
  int closeCount = 0;

  @override
  void close({bool force = false}) => closeCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _AttemptsDatasource extends RecoverBullRemoteDatasource {
  _AttemptsDatasource({required super.log})
    : super(recoverbullSettingsDatasource: _Settings());

  @override
  Future<AttemptsResult> attempts({
    required RecoverBullTorRoute route,
    String? etag,
    List<String> backupIdHashes = const [],
  }) async => AttemptsNotModified();
}

void main() {
  RecoverBullTorRoute routeFor(HttpClient client) => RecoverBullTorRoute(
    TorRoute(
      source: TorSource.embedded,
      endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
      evidence: TorReadinessEvidence.embeddedBootstrap,
    ),
    () async {},
    client,
  );

  test('info and fetch reuse the route client without closing it', () async {
    final settings = _Settings();
    final client = _Client();
    final route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      () async {},
      client,
    );
    final clients = <HttpClient>[];
    final datasource = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      infoRequest: (_, client) async => clients.add(client),
      fetchRequest: (_, client, _, _, _) async {
        clients.add(client);
        return FetchBackupKeyResult(backupKey: [1], attemptStatus: null);
      },
    );
    when(
      () => settings.fetch(),
    ).thenAnswer((_) async => Uri.parse('http://key.onion'));

    await datasource.checkConnection(route);
    await datasource.fetchWithStatus([1], [2], [3], route: route);

    expect(clients, hasLength(2));
    expect(identical(clients[0], route.client), isTrue);
    expect(identical(clients[1], route.client), isTrue);
    expect(identical(clients[0], clients[1]), isTrue);
    expect(client.closeCount, 0);

    await route.close();
    expect(client.closeCount, 1);
  });

  test('rejects an arbitrary HTTPS server before making a request', () async {
    final settings = _Settings();
    var requested = false;
    final datasource = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      infoRequest: (_, _) async => requested = true,
    );
    when(
      () => settings.fetch(),
    ).thenAnswer((_) async => Uri.parse('https://example.com/key-server'));
    final route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      () async {},
      _Client(),
    );

    await expectLater(
      datasource.checkConnection(route),
      throwsA(isA<ArgumentError>()),
    );
    expect(requested, isFalse);
  });

  test(
    'times out a stalled key-server fetch after the bounded deadline',
    () async {
      final settings = _Settings();
      final stalled = Completer<FetchBackupKeyResult>();
      final datasource = RecoverBullRemoteDatasource(
        log: const TestLogSink(),
        recoverbullSettingsDatasource: settings,
        fetchRequest: (_, _, _, _, _) => stalled.future,
        operationTimeout: Duration.zero,
      );
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => Uri.parse('http://key.onion'));
      final route = RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
        () async {},
        _Client(),
      );
      await expectLater(
        datasource.fetchWithStatus([1], [2], [3], route: route),
        throwsA(isA<TimeoutException>()),
      );
    },
  );

  test('uses the dedicated health-check deadline', () async {
    final settings = _Settings();
    final stalled = Completer<void>();
    final datasource = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      infoRequest: (_, _) => stalled.future,
      operationTimeout: const Duration(hours: 1),
      healthCheckTimeout: Duration.zero,
    );
    when(
      () => settings.fetch(),
    ).thenAnswer((_) async => Uri.parse('http://key.onion'));
    final route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      () async {},
      _Client(),
    );

    await expectLater(
      datasource.checkConnection(route),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('polling keeps a successful result when route close fails', () async {
    final route = RecoverBullTorRoute(
      TorRoute(
        source: TorSource.embedded,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
        evidence: TorReadinessEvidence.embeddedBootstrap,
      ),
      () async => throw StateError('close failed'),
      _Client(),
    );
    final adapter = RecoverBullAttemptMonitoringRemoteAdapter(
      datasource: _AttemptsDatasource(log: const TestLogSink()),
      routeFactory: () async => route,
    );

    final result = await adapter.poll(etag: null, backupDigests: const []);

    expect(result, isNotNull);
    expect(result!.notModified, isTrue);
  });

  test(
    'attempts logs modified and not-modified outcomes without identifiers',
    () async {
      final settings = _Settings();
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => Uri.parse('http://sentinel.onion'));
      final log = TestLogSink.recording();
      final datasource = RecoverBullRemoteDatasource(
        log: log,
        recoverbullSettingsDatasource: settings,
        attemptsRequest: (_, _, _, _) async => AttemptsModified(
          etag: 'etag-sentinel',
          maxAgeSeconds: 1,
          version: 1,
          collectionStartedAt: DateTime.utc(2026),
          totalEntries: 4,
          matchingEntries: [
            AttemptEntry(
              idHash: 'digest-sentinel',
              totalAttempts: 3,
              totalRequests: 3,
              failedAttempts: 3,
              windowStartedAt: DateTime.utc(2026),
              lastAttemptAt: DateTime.utc(2026),
            ),
          ],
        ),
      );
      final route = routeFor(_Client());

      await datasource.attempts(
        route: route,
        etag: 'etag-sentinel',
        backupIdHashes: ['digest-sentinel'],
      );

      expect(
        log.entries.single.message,
        contains('outcome=modified matching_count=1'),
      );
      expect(log.entries.single.message, isNot(contains('sentinel')));

      final notModifiedLog = TestLogSink.recording();
      final notModifiedDatasource = RecoverBullRemoteDatasource(
        log: notModifiedLog,
        recoverbullSettingsDatasource: settings,
        attemptsRequest: (_, _, _, _) async => AttemptsNotModified(),
      );

      await notModifiedDatasource.attempts(route: routeFor(_Client()));

      expect(
        notModifiedLog.entries.single.message,
        contains('outcome=not_modified matching_count=0'),
      );
    },
  );

  test(
    'attempts classifies expected and unexpected failures without raw details',
    () async {
      final settings = _Settings();
      when(
        () => settings.fetch(),
      ).thenAnswer((_) async => Uri.parse('http://sentinel.onion'));
      for (final error in <Object>[
        KeyServerException(code: 503, message: 'sentinel payload'),
        KeyServerException(code: 429, message: 'sentinel payload'),
        TimeoutException('sentinel timeout'),
        StateError('sentinel state'),
      ]) {
        final log = TestLogSink.recording();
        final datasource = RecoverBullRemoteDatasource(
          log: log,
          recoverbullSettingsDatasource: settings,
          attemptsRequest: (_, _, _, _) async => throw error,
        );
        await expectLater(
          datasource.attempts(route: routeFor(_Client())),
          throwsA(same(error)),
        );
        expect(log.entries, hasLength(1));
        expect(log.entries.single.message, isNot(contains('sentinel')));
        expect(log.entries.single.error, isNull);
        if (error is KeyServerException && error.code == 429) {
          expect(
            log.entries.single.message,
            'recoverbull.attempts.poll.rate_limited code=429 '
            'attempts=unknown retry_after_seconds=unknown',
          );
        }
        if (error is StateError) {
          expect(log.entries.single.trace, isNotNull);
          expect(
            log.entries.single.trace.toString(),
            isNot(contains('sentinel')),
          );
        }
      }
    },
  );

  test('attempts logs safe rate-limit metadata', () async {
    final settings = _Settings();
    when(
      () => settings.fetch(),
    ).thenAnswer((_) async => Uri.parse('http://sentinel.onion'));
    final log = TestLogSink.recording();
    final datasource = RecoverBullRemoteDatasource(
      log: log,
      recoverbullSettingsDatasource: settings,
      attemptsRequest: (_, _, _, _) async => throw KeyServerException(
        code: 429,
        attempts: 3,
        retryAfter: const Duration(seconds: 47),
        message: 'sentinel payload',
      ),
    );

    await expectLater(
      datasource.attempts(route: routeFor(_Client())),
      throwsA(isA<KeyServerException>()),
    );

    expect(
      log.entries.single.message,
      'recoverbull.attempts.poll.rate_limited code=429 attempts=3 '
      'retry_after_seconds=47',
    );
    expect(log.entries.single.message, isNot(contains('sentinel')));
    expect(log.entries.single.error, isNull);
  });

  test('reports timings for every remote phase and terminal outcome', () async {
    final settings = _Settings();
    when(
      () => settings.fetch(),
    ).thenAnswer((_) async => Uri.parse('http://key.onion'));
    final timings = <({String phase, int duration, String outcome})>[];
    void recordTiming(String phase, int duration, String outcome) {
      timings.add((phase: phase, duration: duration, outcome: outcome));
    }

    final datasource = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      timing: recordTiming,
      infoRequest: (_, _) async {},
      storeRequest: (_, _, _, _, _, _) async {},
      fetchRequest: (_, _, _, _, _) async =>
          FetchBackupKeyResult(backupKey: [1], attemptStatus: null),
      trashRequest: (_, _, _, _, _) async =>
          FetchBackupKeyResult(backupKey: [1], attemptStatus: null),
      attemptsRequest: (_, _, _, _) async => AttemptsNotModified(),
    );
    final route = routeFor(_Client());

    await datasource.info(route);
    await datasource.checkConnection(route);
    await datasource.store([1], [2], [3], [4], route: route);
    await datasource.fetchWithStatus([1], [2], [3], route: route);
    await datasource.trashWithStatus([1], [2], [3], route: route);
    await datasource.attempts(route: route);

    expect(timings.map((timing) => (timing.phase, timing.outcome)), [
      ('server_info', 'success'),
      ('server_health', 'success'),
      ('store_key', 'success'),
      ('fetch_key', 'success'),
      ('trash_key', 'success'),
      ('attempts_poll', 'success'),
    ]);
    expect(timings.every((timing) => timing.duration >= 0), isTrue);

    final failed = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      timing: recordTiming,
      fetchRequest: (_, _, _, _, _) async => throw StateError('sentinel'),
    );
    await expectLater(
      failed.fetchWithStatus([1], [2], [3], route: route),
      throwsA(isA<StateError>()),
    );

    final stalled = Completer<FetchBackupKeyResult>();
    final timedOut = RecoverBullRemoteDatasource(
      log: const TestLogSink(),
      recoverbullSettingsDatasource: settings,
      timing: recordTiming,
      operationTimeout: Duration.zero,
      fetchRequest: (_, _, _, _, _) => stalled.future,
    );
    await expectLater(
      timedOut.fetchWithStatus([1], [2], [3], route: route),
      throwsA(isA<TimeoutException>()),
    );

    expect(timings[timings.length - 2].outcome, 'failure');
    expect(timings.last.outcome, 'timeout');
  });
}
