import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:socks5_proxy/enums.dart';
import 'package:socks5_proxy/exceptions.dart';
import 'package:socks5_proxy/socks_client.dart';

import '../domain/entities/tor_connect_failure.dart';
import '../domain/entities/tor_proxy_endpoint.dart';
import '../domain/tor_failure.dart';
import 'tor_connection_failure_recorder.dart';

@visibleForTesting
Future<void> cancelSocket(FutureOr<void> Function() destroy) async {
  try {
    await destroy();
  } catch (_) {
    // Cancellation must never escape, including when destruction fails
    // synchronously or asynchronously.
  }
}

/// Builds an HTTP client for an already-selected Tor route.
///
/// Cancellation closes the TCP dial and a pending SOCKS negotiation. Once
/// `SecureSocket.secure` detaches that TCP handle, its public API exposes no
/// cancellation handle until the TLS handshake finishes. A cancelled TLS
/// result is destroyed on completion; this does not promise immediate
/// interruption of a silent peer after its ClientHello.
///
/// [endpoint] is deliberately non-nullable. Accepting null meant "return a
/// plain, unproxied client", and the only consumer is the RecoverBull key
/// server — an onion address. A caller that passed null would have shipped its
/// request over clearnet to a hidden-service name, so the route is a
/// requirement the compiler enforces rather than a default the caller can
/// forget.
final class TorHttpClientFactory {
  const TorHttpClientFactory();

  @visibleForTesting
  Future<ConnectionTask<Socket>> createTaskForTesting(
    Uri uri,
    TorProxyEndpoint endpoint, {
    void Function()? onUnderlyingReady,
  }) => _createTask(uri, endpoint, onUnderlyingReady: onUnderlyingReady);

  HttpClient create(
    TorProxyEndpoint endpoint, {
    TorConnectionFailureRecorder? failureRecorder,
    void Function(TorConnectFailure failure)? onConnectFailure,
  }) {
    // The proxy endpoint is loopback by product contract. The destination
    // hostname is intentionally left to socks5_proxy so SOCKS5 can send it as
    // ATYP DOMAINNAME instead of resolving it on the device.
    final address = InternetAddress.tryParse(endpoint.host);
    if (address == null) {
      throw TorBackendException(
        TorUnexpectedFailure(
          'SOCKS5 proxy host is not an IP literal: ${endpoint.host}',
        ),
      );
    }

    final client = HttpClient();
    final recorder = failureRecorder;
    final proxy = ProxySettings(address, endpoint.port, password: null);
    client.connectionFactory = (uri, _, _) async {
      try {
        final task = await _createTask(uri, endpoint, proxy: proxy);
        if (recorder == null && onConnectFailure == null) return task;
        final socket = task.socket.then(
          (value) => value,
          onError: (Object error, StackTrace trace) {
            recorder?.record(error);
            onConnectFailure?.call(classify(error));
            Error.throwWithStackTrace(error, trace);
          },
        );
        return ConnectionTask.fromSocket(socket, task.cancel);
      } catch (error) {
        recorder?.record(error);
        onConnectFailure?.call(classify(error));
        rethrow;
      }
    };
    return client;
  }

  Future<ConnectionTask<Socket>> _createTask(
    Uri uri,
    TorProxyEndpoint endpoint, {
    ProxySettings? proxy,
    void Function()? onUnderlyingReady,
  }) async {
    final settings =
        proxy ??
        ProxySettings(
          InternetAddress(endpoint.host),
          endpoint.port,
          password: null,
        );
    Socket? underlying;
    ConnectionTask<Socket>? connecting;
    var cancelled = false;
    final parentZone = Zone.current;
    // The package owns SOCKS framing and its typed failures, but exposes the
    // socket only after negotiation. Capture just its TCP dial in a local
    // zone so cancellation can close a silent proxy before negotiation ends.
    final socket = IOOverrides.runZoned(
      () => SocksTCPClient.connect(
        [settings],
        InternetAddress(uri.host, type: InternetAddressType.unix),
        uri.port,
      ),
      socketConnect:
          (host, port, {sourceAddress, sourcePort = 0, timeout}) async {
            if (cancelled) {
              throw const SocketException('SOCKS connection cancelled');
            }
            // Dial outside our override, preserving the caller's IO context
            // without recursively intercepting this connection.
            final task = await parentZone.run(
              () => Socket.startConnect(
                host,
                port,
                sourceAddress: sourceAddress,
                sourcePort: sourcePort,
              ),
            );
            connecting = task;
            // Cancellation may win before startConnect returns its handle.
            // Observe the dial future even when we never await it below.
            task.socket.ignore();
            if (cancelled) {
              task.cancel();
              throw const SocketException('SOCKS connection cancelled');
            }
            final raw = timeout == null
                ? await task.socket
                : await task.socket.timeout(
                    timeout,
                    onTimeout: () {
                      task.cancel();
                      throw const SocketException(
                        'SOCKS proxy connection timed out',
                      );
                    },
                  );
            underlying = raw;
            if (cancelled) {
              raw.destroy();
              throw const SocketException('SOCKS connection cancelled');
            }
            return raw;
          },
    );
    Future<void> cancel() async {
      cancelled = true;
      // Destroy synchronously before yielding: TLS may otherwise detach the
      // raw socket during this turn and make its old handle ineffective.
      await cancelSocket(() => underlying?.destroy());
      await cancelSocket(() => connecting?.cancel());
    }

    // Observe failures even when cancellation has detached the HTTP request;
    // a failed handshake must not retain the TCP socket or escape its zone.
    unawaited(
      socket.then<void>(
        (_) {},
        onError: (Object error, StackTrace trace) =>
            cancelSocket(() => underlying?.destroy()),
      ),
    );
    if (uri.scheme == 'https') {
      final secureSocket = socket.then((raw) async {
        // Cancelled while the tunnel was still opening: there is no handshake
        // left to wait for, so the raw socket goes now rather than after TLS.
        if (cancelled) {
          raw.destroy();
          throw const SocketException('Connection cancelled before TLS');
        }
        onUnderlyingReady?.call();
        final secure = await raw.secure(uri.host);
        underlying = secure;
        if (cancelled) {
          secure.destroy();
          throw const SocketException('Connection cancelled during TLS');
        }
        return secure;
      });
      unawaited(
        secureSocket.then<void>(
          (_) {},
          onError: (Object error, StackTrace trace) =>
              cancelSocket(() => underlying?.destroy()),
        ),
      );
      return ConnectionTask.fromSocket(secureSocket, cancel);
    }
    return ConnectionTask.fromSocket(socket, cancel);
  }

  /// Maps a connection error to the reason it carries.
  static TorConnectFailure classify(Object error) => switch (error) {
    SocksClientConnectionCommandFailedException(:final code) => switch (code) {
      CommandReplyCode.ttlExpired => TorConnectFailure.timeout,
      CommandReplyCode.networkUnreachable =>
        TorConnectFailure.torNetworkUnreachable,
      CommandReplyCode.hostUnreachable => TorConnectFailure.hostUnreachable,
      CommandReplyCode.connectionRefused => TorConnectFailure.refused,
      _ => TorConnectFailure.other,
    },
    SocketException() => TorConnectFailure.proxyUnreachable,
    _ => TorConnectFailure.other,
  };
}
