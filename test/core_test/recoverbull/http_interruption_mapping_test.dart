import 'dart:io';

import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_remote_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/datasources/recoverbull_settings_datasource.dart';
import 'package:bb_mobile/core/recoverbull/data/recoverbull_repository_impl.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
      registerFallbackValue(<int>[]);
      registerFallbackValue(endpoint);
      final remote = _Remote();
      when(
        () =>
            remote.fetch(any(), any(), any(), endpoint: any(named: 'endpoint')),
      ).thenThrow(observedError!);
      final repository = RecoverBullRepositoryImpl(
        remoteDatasource: remote,
        recoverbullSettingsDatasource: _Settings(),
      );
      final result = await repository.fetchVaultKey(
        '00',
        'password',
        '00',
        endpoint,
      );
      expect(
        (result as Err<String, RecoverBullCoreFailure>).failure,
        isA<KeyServerUnavailableFailure>(),
      );
    },
  );
}
