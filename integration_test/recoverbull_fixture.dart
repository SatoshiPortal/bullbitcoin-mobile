import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_tor/tor.dart';

/// An in-memory key server behind a SOCKS endpoint that can reach only this
/// fixture. It never resolves or connects to the requested hostname.
final class RecoverBullFixture implements RecoverBullRoutePort {
  final HttpServer _server;
  final ServerSocket _proxy;
  final Set<Socket> _sockets = {};
  Map<String, dynamic>? _stored;
  int fetches = 0;
  int routes = 0;

  RecoverBullFixture._(this._server, this._proxy) {
    _server.listen(_handleRequest);
    _proxy.listen(_handleProxy);
  }

  static Future<RecoverBullFixture> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    try {
      final proxy = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      return RecoverBullFixture._(server, proxy);
    } catch (_) {
      await server.close(force: true);
      rethrow;
    }
  }

  int get port => _server.port;

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      if (body is! Map<String, dynamic>) {
        request.response.statusCode = HttpStatus.badRequest;
      } else if (request.method == 'POST' && request.uri.path == '/store') {
        _stored = body;
        request.response.statusCode = HttpStatus.created;
      } else if (request.method == 'POST' && request.uri.path == '/fetch') {
        fetches++;
        final stored = _stored;
        if (stored == null ||
            stored['identifier'] != body['identifier'] ||
            stored['authentication_key'] != body['authentication_key']) {
          request.response.statusCode = HttpStatus.unauthorized;
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'encrypted_secret': stored['encrypted_secret']}),
          );
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } finally {
      await request.response.close();
    }
  }

  void _handleProxy(Socket client) {
    _sockets.add(client);
    Socket? target;
    var stage = 0;
    final buffer = <int>[];

    void consume() {
      if (stage == 0 && buffer.length >= 2) {
        final length = 2 + buffer[1];
        if (buffer.length < length) return;
        if (buffer[0] != 5 || !buffer.sublist(2, length).contains(0)) {
          client.destroy();
          return;
        }
        buffer.removeRange(0, length);
        client.add([5, 0]);
        stage = 1;
      }
      if (stage == 1 && buffer.length >= 5) {
        final length = 7 + buffer[4];
        if (buffer.length < length) return;
        final host = ascii.decode(buffer.sublist(5, length - 2));
        final port = (buffer[length - 2] << 8) | buffer[length - 1];
        if (buffer[0] != 5 ||
            buffer[1] != 1 ||
            buffer[3] != 3 ||
            host != 'fixture.onion' ||
            port != 80) {
          client.destroy();
          return;
        }
        buffer.removeRange(0, length);
        stage = 2;
        Socket.connect(InternetAddress.loopbackIPv4, _server.port).then((peer) {
          target = peer;
          _sockets.add(peer);
          peer.listen(
            client.add,
            onDone: client.destroy,
            onError: (_) => client.destroy(),
          );
          client.add([5, 0, 0, 1, 127, 0, 0, 1, 0, 0]);
          stage = 3;
          if (buffer.isNotEmpty) {
            peer.add(buffer);
            buffer.clear();
          }
        }, onError: (_) => client.destroy());
      }
      if (stage == 3 && buffer.isNotEmpty) {
        target?.add(buffer);
        buffer.clear();
      }
    }

    client.listen(
      (data) {
        buffer.addAll(data);
        consume();
      },
      onDone: () {
        target?.destroy();
        _sockets.remove(client);
      },
      onError: (_) {
        target?.destroy();
        _sockets.remove(client);
      },
    );
  }

  @override
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
    bool viaSnowflake = false,
  }) async {
    routes++;
    return Ok(
      RecoverBullRoute(
        TorRoute(
          source: TorSource.external,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: _proxy.port),
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
        () async {},
      ),
    );
  }

  @override
  bool get snowflakeAvailable => false;

  @override
  Stream<TorConnectionState> watch() => const Stream.empty();

  Future<void> close() async {
    await _proxy.close();
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _server.close(force: true);
  }
}

final class RecoverBullTestPermission implements RecoverBullPermissionPort {
  bool _granted = false;
  int _revision = 0;

  @override
  Future<Result<({bool granted, int revision}), RecoverBullFailure>>
  readPermission() async => Ok((granted: _granted, revision: _revision));

  @override
  Future<Result<void, RecoverBullFailure>> savePermission(bool granted) async {
    if (_granted != granted) {
      _granted = granted;
      _revision++;
    }
    return const Ok(null);
  }
}
