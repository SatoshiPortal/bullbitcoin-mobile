import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bull_reporting/src/metrics/statistics_transport.dart';

void main() {
  late HttpServer server;
  late List<String> requests;
  late StatisticsTransport transport;

  setUp(() async {
    requests = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      requests.add(await utf8.decoder.bind(request).join());
      await request.response.close();
    });
    transport = StatisticsTransport(
      'http://public@127.0.0.1:${server.port}/1',
      '6.16.0+220',
      'regtest',
    );
  });

  tearDown(() async {
    transport.updateConsent(false);
    await server.close(force: true);
  });

  test('default off and withdrawal discard queued observations', () async {
    transport.installationActive(DateTime.utc(2026, 11, 25));
    await transport.flush();
    transport.updateConsent(true);
    transport.installationActive(DateTime.utc(2026, 11, 25));
    transport.updateConsent(false);
    transport.updateConsent(true);
    await transport.flush();
    expect(requests, isEmpty);
  });

  test('sends only the daily metric and its approved attributes', () async {
    transport.updateConsent(true);
    transport.installationActive(DateTime.utc(2026, 11, 25));
    await transport.flush();
    final lines = requests.single.split('\n');
    expect(lines.first, '{}');
    final envelope = jsonDecode(lines[1]) as Map<String, dynamic>;
    expect(envelope['type'], 'trace_metric');
    expect(envelope['item_count'], 1);
    expect(envelope['length'], utf8.encode(lines[2]).length);
    final payload = jsonDecode(lines[2]) as Map<String, dynamic>;
    final item = (payload['items'] as List<dynamic>).single as Map;
    expect(item.keys.toSet(), {
      'name',
      'type',
      'value',
      'timestamp',
      'trace_id',
      'attributes',
    });
    expect(item['name'], 'bull.installation.active');
    expect(item['type'], 'counter');
    expect(item['value'], 1);
    expect(
      item['timestamp'],
      DateTime.utc(2026, 11, 25).millisecondsSinceEpoch / 1000,
    );
    expect(item['trace_id'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(item['attributes'], {
      'sentry.release': {'type': 'string', 'value': '6.16.0+220'},
      'sentry.environment': {'type': 'string', 'value': 'regtest'},
    });
  });

  test('invalid build environment or endpoint stays unavailable', () {
    final invalid = StatisticsTransport(
      'http://example.com/1',
      '1+1',
      'unknown',
    );
    expect(invalid.available, isFalse);
    invalid.updateConsent(true);
    invalid.installationActive(DateTime.now());
  });

  test('revocation terminates a request awaiting a response', () async {
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final received = Completer<void>();
    final finish = Completer<void>();
    server.listen((request) async {
      await request.drain<void>();
      received.complete();
      await finish.future;
      try {
        await request.response.close();
      } on Exception {
        // Revocation is allowed to close the connection.
      }
    });
    transport = StatisticsTransport(
      'http://public@127.0.0.1:${server.port}/1',
      '6.16.0+220',
      'regtest',
    );
    transport.updateConsent(true);
    transport.installationActive(DateTime.utc(2026, 11, 25));
    final sending = transport.flush();
    await received.future;
    transport.updateConsent(false);
    await sending.timeout(const Duration(seconds: 3));
    finish.complete();
  });
}
