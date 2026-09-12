import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:socks5_proxy/socks_client.dart';

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
        if (recorder == null) return task;
        final socket = task.socket.then(
          (value) => value,
          onError: (Object error, StackTrace trace) {
            recorder.record(error);
            Error.throwWithStackTrace(error, trace);
          },
        );
        return ConnectionTask.fromSocket(socket, task.cancel);
      } catch (error) {
        recorder?.record(error);
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
    final socket = SocksTCPClient.connect(
      [settings],
      InternetAddress(uri.host, type: InternetAddressType.unix),
      uri.port,
    );
    if (uri.scheme == 'https') {
      Socket? underlying;
      final secureSocket = socket.then((raw) {
        underlying = raw;
        onUnderlyingReady?.call();
        return raw.secure(uri.host);
      });
      unawaited(
        secureSocket.then<void>(
          (_) {},
          onError: (Object error, StackTrace trace) => underlying?.destroy(),
        ),
      );
      return ConnectionTask.fromSocket(secureSocket, () async {
        await cancelSocket(() => underlying?.destroy());
        await cancelSocket(() async => (await secureSocket).destroy());
      });
    }
    return ConnectionTask.fromSocket(
      socket,
      () => cancelSocket(() async => (await socket).destroy()),
    );
  }
}
