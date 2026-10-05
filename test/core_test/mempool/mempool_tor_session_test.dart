import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_tor_session_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/mempool_tor_session_adapter.dart';
import 'package:bb_mobile/core/mempool/interface_adapters/validators/http_mempool_server_validator.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockTor extends Mock implements Tor {}

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockTorSessions extends Mock implements TorSessions {}

class _FakeSessionPort implements MempoolTorSessionPort {
  _FakeSessionPort({this.error});

  final Object? error;
  final opened = <String>[];
  var closed = 0;

  @override
  Future<MempoolTorRoute?> open({required String serverUrl}) async {
    opened.add(serverUrl);
    if (error != null) throw error!;
    return MempoolTorRoute(
      TorProxyEndpoint(host: '127.0.0.1', port: 1),
      () async => closed++,
    );
  }
}

void main() {
  group('MempoolTorSessionAdapter', () {
    test('opens and closes an isolated onion session', () async {
      final tor = _MockTor();
      final embedded = _MockEmbeddedTor();
      final sessions = _MockTorSessions();
      var closed = false;
      final session = TorSession(
        TorProxyEndpoint(host: '127.0.0.1', port: 9050),
        TorTransport.direct,
        () async => closed = true,
      );
      when(() => tor.embedded).thenReturn(embedded);
      when(() => embedded.sessions).thenReturn(sessions);
      when(() => sessions.open()).thenAnswer((_) async => session);

      final route = await MempoolTorSessionAdapter(
        () => tor,
      ).open(serverUrl: 'https://hidden.onion');

      expect(route?.endpoint.port, 9050);
      await route?.close();
      expect(closed, isTrue);
      verify(() => sessions.open()).called(1);
    });

    test('does not open a session for clearnet', () async {
      final tor = _MockTor();
      final route = await MempoolTorSessionAdapter(
        () => tor,
      ).open(serverUrl: 'https://example.com');

      expect(route, isNull);
      verifyNever(() => tor.embedded);
    });
  });

  group('HttpMempoolServerValidator Tor routing', () {
    const factory = TorHttpClientFactory();

    test('closes the onion route after validation', () async {
      final sessions = _FakeSessionPort();
      final validator = HttpMempoolServerValidator(
        torSessionPort: sessions,
        torHttpClientFactory: factory,
      );

      await validator.validateServer(
        url: 'hidden.onion',
        network: MempoolServerNetwork.bitcoinMainnet,
      );

      expect(sessions.opened, ['https://hidden.onion']);
      expect(sessions.closed, 1);
    });

    test('returns Tor failure without falling back to clearnet', () async {
      final sessions = _FakeSessionPort(error: Exception('Tor unavailable'));
      final validator = HttpMempoolServerValidator(
        torSessionPort: sessions,
        torHttpClientFactory: factory,
      );

      final result = await validator.validateServer(
        url: 'hidden.onion',
        network: MempoolServerNetwork.bitcoinMainnet,
      );

      expect(result, isA<Err<void, MempoolFailure>>());
      expect(
        (result as Err).failure,
        isA<MempoolValidationTorNotRunningFailure>(),
      );
      expect(sessions.opened, ['https://hidden.onion']);
    });

    test('does not open Tor for clearnet validation', () async {
      final sessions = _FakeSessionPort();
      final validator = HttpMempoolServerValidator(
        torSessionPort: sessions,
        torHttpClientFactory: factory,
      );

      await validator.validateServer(
        url: '127.0.0.1:1',
        network: MempoolServerNetwork.bitcoinMainnet,
        enableSsl: false,
      );

      expect(sessions.opened, isEmpty);
    });
  });
}
