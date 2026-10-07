import 'dart:io';

import 'package:bull_recoverbull/src/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bull_recoverbull/src/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bull_recoverbull/src/data/recoverbull_repository_impl.dart';
import 'package:bull_recoverbull/src/domain/entities/key_server_attempts.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../support/log_sink.dart';

class _Remote extends Mock implements RecoverBullRemoteDatasource {}

class _Settings extends Mock implements RecoverbullSettingsDatasource {}

void main() {
  test(
    'an interrupted HTTP response maps to key-server unavailability',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <Socket>[];
      final subscription = server.listen((socket) {
        sockets.add(socket);
        socket.listen((_) => socket.destroy());
      });
      final client = HttpClient();
      Object? observedError;
      try {
        final request = await client.postUrl(
          Uri.parse('http://127.0.0.1:${server.port}/fetch'),
        );
        request.write('{}');
        try {
          await request.close().timeout(const Duration(seconds: 3));
        } catch (error) {
          observedError = error;
        }
      } finally {
        client.close(force: true);
        for (final socket in sockets) {
          socket.destroy();
        }
        await subscription.cancel();
        await server.close();
      }

      // First prove this is an actual HTTP transport exception, not an invented
      // foreign error or a mock that bypasses the failing I/O boundary.
      expect(observedError, isA<HttpException>());
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 9050);
      final route = RecoverBullTorRoute(
        TorRoute(
          source: TorSource.embedded,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
        () async {},
        HttpClient(),
      );
      addTearDown(route.closeQuietly);
      registerFallbackValue(<int>[]);
      registerFallbackValue(route);
      final remote = _Remote();
      when(
        () => remote.fetch(any(), any(), any(), route: any(named: 'route')),
      ).thenThrow(observedError!);
      when(
        () => remote.fetchWithStatus(
          any(),
          any(),
          any(),
          route: any(named: 'route'),
        ),
      ).thenThrow(observedError);
      final repository = RecoverBullRepositoryImpl(
        log: const TestLogSink(),
        remoteDatasource: remote,
        recoverbullSettingsDatasource: _Settings(),
      );

      final result = await repository.fetchVaultKey(
        '00',
        'password',
        '00',
        route,
      );
      expect(
        (result as Err<String, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );

      final withStatus = await repository.fetchVaultKeyWithStatus(
        '00',
        'password',
        '00',
        route,
      );
      expect(
        (withStatus as Err<VaultKeyFetchResult, RecoverBullFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    },
  );
}
