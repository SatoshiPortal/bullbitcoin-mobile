import 'dart:async';
import 'dart:io';

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
  _AttemptsDatasource() : super(recoverbullSettingsDatasource: _Settings());

  @override
  Future<AttemptsResult> attempts({
    required RecoverBullTorRoute route,
    String? etag,
    List<String> backupIdHashes = const [],
  }) async => AttemptsNotModified();
}

void main() {
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
      datasource: _AttemptsDatasource(),
      routeFactory: () async => route,
    );

    final result = await adapter.poll(etag: null, backupDigests: const []);

    expect(result, isNotNull);
    expect(result!.notModified, isTrue);
  });
}
