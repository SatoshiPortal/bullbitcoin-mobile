import 'dart:async';

import 'package:bull_payjoin/src/engine/payjoin_engine_exception.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bull_payjoin/src/domain/payjoin_regtest_profile.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meta/meta.dart';
import 'package:payjoin/payjoin.dart' show OhttpKeys;
import 'package:primitives/primitives.dart';

/// Private client family for one regtest-only runtime with explicit private trust.
final class PayjoinRegtestTransport {
  final PayjoinRegtestProfile _profile;
  final NetworkEnv _environment;
  final Future<bool> Function()? _isCurrent;
  final Set<Future<void>> _pending = {};
  final Set<void Function()> _cancel = {};
  bool _closed = false;
  final SecurityContext _securityContext;
  final Future<ConnectionTask<Socket>> Function(String, int) _startConnect;
  final Future<SecureSocket> Function(Socket, String, SecurityContext) _secure;

  PayjoinRegtestTransport({
    required PayjoinRegtestProfile profile,
    required NetworkEnv environment,
    this._isCurrent,
    @visibleForTesting
    Future<ConnectionTask<Socket>> Function(String, int)? startConnect,
    @visibleForTesting
    Future<SecureSocket> Function(Socket, String, SecurityContext)? secure,
  }) : _profile = profile,
       _environment = environment,
       _securityContext = _trustContext(profile, environment),
       _startConnect =
           startConnect ?? ((host, port) => Socket.startConnect(host, port)),
       _secure = secure ?? _secureSocket;

  static Future<SecureSocket> _secureSocket(
    Socket socket,
    String host,
    SecurityContext context,
  ) => SecureSocket.secure(socket, host: host, context: context);

  static SecurityContext _trustContext(
    PayjoinRegtestProfile profile,
    NetworkEnv environment,
  ) {
    if (environment != NetworkEnv.regtest) {
      throw const HttpException('Regtest Payjoin context is unavailable');
    }
    final encoded = base64Encode(profile.certificateDer);
    final lines = [
      for (var start = 0; start < encoded.length; start += 64)
        encoded.substring(
          start,
          start + 64 < encoded.length ? start + 64 : encoded.length,
        ),
    ];
    final pem =
        '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n-----END CERTIFICATE-----\n';
    return SecurityContext(withTrustedRoots: false)
      ..setTrustedCertificatesBytes(
        Platform.isIOS ? profile.certificateDer : utf8.encode(pem),
      );
  }

  void _requireCurrent() {
    if (_closed || _environment != NetworkEnv.regtest) {
      throw const HttpException('Regtest Payjoin context is unavailable');
    }
  }

  Future<void> _requireActive() async {
    _requireCurrent();
    final current = _isCurrent;
    if (current != null && !await current()) {
      throw const PayjoinRuntimeInactiveException();
    }
    _requireCurrent();
  }

  Future<T> _track<T>(Future<T> Function() operation) {
    _requireCurrent();
    final result = Future<T>.sync(operation);
    final joined = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _pending.add(joined);
    unawaited(joined.whenComplete(() => _pending.remove(joined)));
    return result;
  }

  /// Close owned IO, then wait for actual TCP/TLS futures, not timeout wrappers.
  Future<void> close() async {
    _closed = true;
    for (final cancel in _cancel.toList()) {
      cancel();
    }
    await Future.wait(_pending.toList());
  }

  bool _matchesCertificate(X509Certificate? certificate) {
    if (certificate == null) return false;
    final now = DateTime.now();
    return !now.isBefore(certificate.startValidity) &&
        now.isBefore(certificate.endValidity) &&
        sha256.convert(certificate.der).toString() ==
            _profile.certificateSha256;
  }

  /// The task is available before DNS/TCP yields a handle. Cancellation never
  /// detaches the actual child future, including a TLS handshake already begun.
  @visibleForTesting
  Future<ConnectionTask<Socket>> connectPinned(Uri endpoint) {
    _requireCurrent();
    _profile.requireEndpoint(endpoint);
    var cancelled = false;
    ConnectionTask<Socket>? tcp;
    Socket? raw;
    SecureSocket? secured;
    void cancel() {
      cancelled = true;
      final pending = tcp;
      tcp = null;
      pending?.cancel();
      final socket = raw;
      raw = null;
      socket?.destroy();
      final tls = secured;
      secured = null;
      tls?.destroy();
    }

    Future<void> check() async {
      if (cancelled) {
        throw const SocketException('Regtest Payjoin connection cancelled');
      }
      await _requireActive();
      if (cancelled) {
        throw const SocketException('Regtest Payjoin connection cancelled');
      }
    }

    _cancel.add(cancel);
    final connected = _track<Socket>(() async {
      var transferred = false;
      try {
        await check();
        final task = await _startConnect(_profile.host, endpoint.port);
        tcp = task;
        if (cancelled || _closed) {
          tcp = null;
          task.cancel();
        }
        // Even after cancellation, observe the real future and destroy a socket
        // delivered late. No timeout wrapper may stand in for its completion.
        final socket = await task.socket;
        raw = socket;
        await check();
        final tls = await _secure(socket, endpoint.host, _securityContext);
        secured = tls;
        await check();
        if (!_matchesCertificate(tls.peerCertificate)) {
          throw const HandshakeException(
            'Regtest Payjoin connection pin mismatch',
          );
        }
        transferred = true;
        return tls;
      } finally {
        _cancel.remove(cancel);
        if (!transferred) cancel();
      }
    });
    return Future.value(ConnectionTask.fromSocket(connected, cancel));
  }

  Dio createDio() {
    _requireCurrent();
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        maxRedirects: 0,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 35),
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        _requireCurrent();
        final client = HttpClient(context: _securityContext);
        client.findProxy = (_) => 'DIRECT';
        client.connectionFactory = (endpoint, proxyHost, proxyPort) {
          if (proxyHost != null || proxyPort != null) {
            throw const HttpException('Unexpected regtest Payjoin proxy');
          }
          return connectPinned(endpoint);
        };
        return client;
      },
      validateCertificate: (certificate, host, port) =>
          _profile.allowsEndpoint(
            Uri(scheme: 'https', host: host, port: port),
          ) &&
          _matchesCertificate(certificate),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            await _requireActive();
            _profile.requireEndpoint(options.uri);
            handler.next(options);
          } on Exception catch (error) {
            handler.reject(DioException(requestOptions: options, error: error));
          }
        },
      ),
    );
    _cancel.add(() => dio.close(force: true));
    return dio;
  }

  /// One joined discovery includes CONNECT, both TLS layers, response/native
  /// decode and cleanup. A deadline requests cancellation; it does not fake a
  /// drain when Dart has detached the raw socket during an opaque handshake.
  Future<OhttpKeys> fetchOhttpKeys({
    required String ohttpRelayUrl,
    required String directoryUrl,
    required Duration timeout,
  }) {
    _requireCurrent();
    final relay = Uri.parse(ohttpRelayUrl);
    final directory = Uri.parse(directoryUrl);
    _profile.requireEndpoint(relay);
    _profile.requireEndpoint(directory);
    if (!_profile
        .relaysFor(directory)
        .any((server) => server.origin == relay.origin)) {
      throw const HttpException('Regtest Payjoin relay role mismatch');
    }
    if (timeout <= Duration.zero) {
      throw const HttpException('Regtest Payjoin discovery budget exhausted');
    }
    return _track(() => _discover(relay, directory, timeout));
  }

  Future<OhttpKeys> _discover(
    Uri relay,
    Uri directory,
    Duration timeout,
  ) async {
    _requireCurrent();
    final tunnelClient = HttpClient(context: _securityContext);
    final client = HttpClient(context: _securityContext);
    ConnectionTask<Socket>? relayTask;
    Socket? relaySocket;
    Socket? tunnel;
    StreamSubscription<List<int>>? tunnelInput;
    SecureSocket? directorySocket;
    var expired = false;
    void cancel() {
      relayTask?.cancel();
      tunnel?.destroy();
      directorySocket?.destroy();
      tunnelClient.close(force: true);
      client.close(force: true);
    }

    Future<void> check() async {
      if (expired) {
        throw TimeoutException(
          'Regtest Payjoin discovery budget exhausted',
          timeout,
        );
      }
      await _requireActive();
      if (expired) {
        throw TimeoutException(
          'Regtest Payjoin discovery budget exhausted',
          timeout,
        );
      }
    }

    _cancel.add(cancel);
    final deadline = Timer(timeout, () {
      expired = true;
      cancel();
    });
    try {
      // HTTP framing for CONNECT travels inside the pinned relay TLS socket.
      // An HTTPS proxy URI here would let HttpClient start inner TLS itself,
      // hiding the lifecycle check between CONNECT and that handshake.
      final connectUri = Uri(
        scheme: 'http',
        host: directory.host,
        port: directory.port,
      );
      tunnelClient.findProxy = (_) => 'PROXY ${relay.host}:${relay.port}';
      tunnelClient.connectionFactory = (uri, host, port) async {
        await check();
        if (uri != connectUri || host != relay.host || port != relay.port) {
          throw const HttpException('Unexpected regtest Payjoin proxy');
        }
        final task = await connectPinned(relay);
        relayTask = task;
        if (expired || _closed) task.cancel();
        return ConnectionTask.fromSocket(
          task.socket.then((socket) {
            relaySocket = socket;
            return socket;
          }),
          task.cancel,
        );
      };
      await check();
      final connect = await tunnelClient.openUrl('CONNECT', connectUri);
      await check();
      connect.followRedirects = false;
      connect.maxRedirects = 0;
      final response = await connect.close();
      await check();
      if (response.statusCode != HttpStatus.ok ||
          !_matchesCertificate(response.certificate)) {
        throw const HttpException('Regtest Payjoin CONNECT refused');
      }
      tunnel = await response.detachSocket();
      await check();
      // Dart 3.14 returns a Socket wrapper that cannot itself be TLS-upgraded.
      // Observe its parser-buffered bytes before upgrading our original socket.
      // The pinned SDK delivers buffered input in the listen microtask before
      // resuming socket reads. This observes the parser remainder, not every
      // later network byte; those remain subject to the real TLS handshake.
      // Pausing retains future bytes in the socket. Re-test on SDK upgrades.
      Object? unexpectedInput;
      tunnelInput = tunnel.listen(
        (bytes) {
          if (bytes.isNotEmpty) {
            unexpectedInput = const HttpException(
              'Unexpected data before regtest directory TLS',
            );
          }
        },
        onError: (Object error) {
          unexpectedInput = error;
        },
        onDone: () {
          unexpectedInput = const HttpException(
            'Regtest Payjoin tunnel closed',
          );
        },
      );
      await Future<void>.value();
      tunnelInput.pause();
      await check();
      final unexpected = unexpectedInput;
      if (unexpected != null) throw unexpected;
      final socket = relaySocket;
      if (socket == null) throw StateError('Missing owned relay socket');
      final secured = await _secure(socket, directory.host, _securityContext);
      directorySocket = secured;
      await check();
      if (!_matchesCertificate(secured.peerCertificate)) {
        throw const HandshakeException(
          'Regtest Payjoin directory pin mismatch',
        );
      }
      var transferred = false;
      client.findProxy = (_) => 'DIRECT';
      client.connectionFactory = (uri, host, port) async {
        await check();
        _profile.requireEndpoint(uri);
        if (uri.origin != directory.origin ||
            host != null ||
            port != null ||
            transferred) {
          throw const HttpException(
            'Unexpected regtest Payjoin directory connection',
          );
        }
        transferred = true;
        return Future.value(
          ConnectionTask.fromSocket(Future.value(secured), secured.destroy),
        );
      };
      await check();
      final request = await client.getUrl(
        directory.resolve('/.well-known/ohttp-gateway'),
      );
      await check();
      request.followRedirects = false;
      request.maxRedirects = 0;
      request.headers.set(HttpHeaders.acceptHeader, 'application/ohttp-keys');
      final keysResponse = await request.close();
      await check();
      if (!_matchesCertificate(keysResponse.certificate) ||
          keysResponse.statusCode < 200 ||
          keysResponse.statusCode >= 300) {
        throw const HttpException('Regtest Payjoin key discovery refused');
      }
      final body = BytesBuilder(copy: false);
      await for (final chunk in keysResponse) {
        await check();
        if (body.length + chunk.length > 1024) {
          throw const HttpException(
            'Regtest Payjoin key response exceeds limit',
          );
        }
        body.add(chunk);
      }
      await check();
      final keys = OhttpKeys.decode(bytes: body.takeBytes());
      await check();
      return keys;
    } on Exception {
      if (expired) {
        throw TimeoutException(
          'Regtest Payjoin discovery budget exhausted',
          timeout,
        );
      }
      rethrow;
    } finally {
      deadline.cancel();
      _cancel.remove(cancel);
      cancel();
      await tunnelInput?.cancel();
    }
  }
}
