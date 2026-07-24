import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

/// Regression coverage for `BoltzDatasource._suppressUnhandledChannelReadyError`.
///
/// `IOWebSocketChannel.connect` exposes a `ready` future that completes with
/// an error when the connection attempt fails (DNS failure, connection
/// refused, etc. — see `AdapterWebSocketChannel` in `web_socket_channel`).
/// Nothing downstream (`boltz_stream`, `BoltzDatasource`) ever awaits that
/// future, so an unhandled error on it is reported to the enclosing zone as
/// an uncaught error. In the app that surfaces in `main.dart`'s
/// `runZonedGuarded` handler as a "Global Unhandled Error" that duplicates
/// the `[Boltz] websocket error` / reconnect warnings already logged for the
/// exact same (recoverable) failure.
///
/// These tests exercise the real `web_socket_channel` failure path against a
/// closed local port (no network access required, deterministic) to prove
/// the no-op handler used in production suppresses the zone escape without
/// masking genuinely unhandled errors elsewhere.
void main() {
  Future<int> closedLocalPort() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    return port;
  }

  test('a failed connection\'s ready error is swallowed and never reaches the '
      'zone once the no-op handler is attached', () async {
    final port = await closedLocalPort();
    Object? zoneError;
    final done = Completer<void>();

    runZonedGuarded(
      () async {
        final channel = IOWebSocketChannel.connect('ws://127.0.0.1:$port/ws');
        // Mirrors BoltzDatasource._suppressUnhandledChannelReadyError.
        unawaited(channel.ready.catchError((_) {}));

        await Future.delayed(const Duration(milliseconds: 500));
        if (!done.isCompleted) done.complete();
      },
      (error, stack) {
        zoneError = error;
        if (!done.isCompleted) done.complete();
      },
    );

    await done.future;
    // Extra buffer in case the uncaught-error report lands in a task
    // queued right after the zone body's own completion.
    await Future.delayed(const Duration(milliseconds: 50));

    expect(zoneError, isNull);
  });

  test('without the no-op handler, the same connection failure escapes to the '
      'zone as an uncaught error (documents the bug being fixed)', () async {
    final port = await closedLocalPort();
    Object? zoneError;
    final done = Completer<void>();

    runZonedGuarded(
      () async {
        // Deliberately not attaching any handler to `channel.ready`.
        IOWebSocketChannel.connect('ws://127.0.0.1:$port/ws');

        await Future.delayed(const Duration(milliseconds: 500));
        if (!done.isCompleted) done.complete();
      },
      (error, stack) {
        zoneError = error;
        if (!done.isCompleted) done.complete();
      },
    );

    await done.future;
    await Future.delayed(const Duration(milliseconds: 50));

    expect(zoneError, isNotNull);
  });
}
