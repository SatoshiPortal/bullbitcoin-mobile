import 'dart:io';

import 'package:bull_recoverbull/src/domain/recoverbull_tor_route.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CountingHttpClient implements HttpClient {
  int closeCount = 0;

  @override
  void close({bool force = false}) {
    closeCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TorRoute _torRoute(int port) => TorRoute(
  source: TorSource.embedded,
  endpoint: TorProxyEndpoint(host: '127.0.0.1', port: port),
  evidence: TorReadinessEvidence.embeddedBootstrap,
);

void main() {
  test('reuses and closes one client per route', () async {
    final client = _CountingHttpClient();
    var sessionCloseCount = 0;
    final route = RecoverBullTorRoute(
      _torRoute(19050),
      () async => sessionCloseCount++,
      client,
    );

    expect(identical(route.client, route.client), isTrue);
    expect(client.closeCount, 0);

    await route.close();
    await route.close();

    expect(client.closeCount, 1);
    expect(sessionCloseCount, 1);
  });

  test('different routes do not share a client', () async {
    final first = RecoverBullTorRoute(
      _torRoute(19050),
      () async {},
      HttpClient(),
    );
    final second = RecoverBullTorRoute(
      _torRoute(19051),
      () async {},
      HttpClient(),
    );

    expect(identical(first.client, second.client), isFalse);
    await first.close();
    await second.close();
  });
}
