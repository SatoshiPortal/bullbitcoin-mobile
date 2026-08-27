import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';

const _connector = ElectrumSocketConnector();
const _timeout = Duration(seconds: 2);

void main() {
  group('onion without a proxy', () {
    test('is refused before any socket is opened', () async {
      await expectLater(
        _connector.connect(
          server: Uri.parse('tcp://qwerty234.onion:50001'),
          timeout: _timeout,
        ),
        throwsA(isA<OnionServerWithoutTorException>()),
      );
    });

    test('is refused for a trailing-dot onion host too', () async {
      await expectLater(
        _connector.connect(
          server: Uri.parse('ssl://qwerty234.onion.:50002'),
          timeout: _timeout,
        ),
        throwsA(isA<OnionServerWithoutTorException>()),
      );
    });

    test('does not refuse a clearnet host that merely contains "onion"', () {
      // `onion.example.com` is a normal domain; refusing it would break a
      // legitimate server for a substring match.
      expect(
        _connector.connect(
          server: Uri.parse('tcp://onion.example.com:50001'),
          timeout: const Duration(milliseconds: 1),
        ),
        throwsA(isNot(isA<OnionServerWithoutTorException>())),
      );
    });
  });

  group('through a proxy', () {
    late _FakeSocksServer proxy;

    setUp(() async => proxy = await _FakeSocksServer.start());
    tearDown(() async => proxy.close());

    /// The DNS-leak regression guard. `socks5_proxy` takes an
    /// `InternetAddress`, so the obvious call resolves the name locally; the
    /// connector works around that. If an upgrade breaks the workaround, the
    /// request below carries ATYP 0x01 and a resolved IP instead of the name,
    /// and this test fails rather than the leak shipping.
    test('sends the hostname as a SOCKS5 domain name, never an IP', () async {
      unawaited(
        _connector
            .connect(
              server: Uri.parse('tcp://qwerty234.onion:50001'),
              timeout: _timeout,
              proxy: TorProxyEndpoint(
                host: InternetAddress.loopbackIPv4.address,
                port: proxy.port,
              ),
            )
            .then<void>((socket) => socket.destroy(), onError: (_) {}),
      );

      final request = await proxy.request;

      expect(request[0], 0x05, reason: 'SOCKS5');
      expect(request[1], 0x01, reason: 'CONNECT');
      expect(
        request[3],
        0x03,
        reason: 'ATYP must be domain-name; 0x01 would mean a local DNS lookup',
      );
      final length = request[4];
      final host = String.fromCharCodes(request.sublist(5, 5 + length));
      expect(host, 'qwerty234.onion');
      final port = (request[5 + length] << 8) | request[6 + length];
      expect(port, 50001);
    });
  });
}

/// A loopback listener that completes the SOCKS5 greeting and then captures the
/// connect request verbatim.
class _FakeSocksServer {
  final ServerSocket _server;
  final Completer<List<int>> _request = Completer<List<int>>();

  _FakeSocksServer(this._server) {
    _server.listen((socket) {
      final buffer = <int>[];
      var greeted = false;
      socket.listen((chunk) {
        if (!greeted) {
          // Client greeting: accept "no authentication".
          greeted = true;
          socket.add([0x05, 0x00]);
          return;
        }
        buffer.addAll(chunk);
        if (!_request.isCompleted) _request.complete(buffer);
      }, onError: (_) {});
    });
  }

  static Future<_FakeSocksServer> start() async => _FakeSocksServer(
    await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
  );

  int get port => _server.port;

  Future<List<int>> get request => _request.future.timeout(_timeout);

  Future<void> close() => _server.close();
}
