import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
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
      'mainnet',
      () async => true,
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
      'sentry.environment': {'type': 'string', 'value': 'mainnet'},
    });
  });

  test('invalid build environment or endpoint stays unavailable', () {
    final invalid = StatisticsTransport(
      'http://example.com/1',
      '1+1',
      'unknown',
      () async => true,
    );
    expect(invalid.available, isFalse);
    invalid.updateConsent(true);
    invalid.installationActive(DateTime.now());
  });

  test('non-mainnet observations are never sent', () async {
    final nonMainnet = StatisticsTransport(
      'http://public@127.0.0.1:${server.port}/1',
      '6.16.0+220',
      'regtest',
      () async => true,
    );
    nonMainnet.updateConsent(true);
    nonMainnet.installationActive(DateTime.utc(2026, 11, 25));
    await nonMainnet.flush();
    expect(requests, isEmpty);
  });

  group('HTTP status', () {
    late Directory logs;

    setUp(() async {
      logs = await Directory.systemTemp.createTemp('statistics-status-');
      await initializeLogging(directory: logs, background: false);
    });

    tearDown(() async {
      await log.flush();
      await logs.delete(recursive: true);
    });

    Future<String> supportLog() async {
      await log.flush();
      final file = File('${logs.path}/bull_logs.tsv');
      return await file.exists() ? file.readAsString() : '';
    }

    for (final status in [200, 204, 400, 429, 500, 503]) {
      final ok = status < 300;
      test('${ok ? 'accepts' : 'records'} $status without a retry', () async {
        await server.close(force: true);
        var received = 0;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        server.listen((request) async {
          received++;
          await request.drain<void>();
          request.response.statusCode = status;
          request.response.headers.set('retry-after', '1');
          request.response.write('secret-response-body');
          await request.response.close();
        });
        final endpoint = 'public@127.0.0.1:${server.port}';
        transport = StatisticsTransport(
          'http://$endpoint/1',
          '6.16.0+220',
          'mainnet',
          () async => true,
        );
        transport.updateConsent(true);
        transport.installationActive(DateTime.utc(2026, 11, 25));

        await transport.flush().timeout(const Duration(seconds: 5));
        // A rejected batch is dropped, never re-sent or re-queued.
        await transport.flush().timeout(const Duration(seconds: 5));
        expect(received, 1);

        final text = await supportLog();
        if (ok) {
          expect(text, isNot(contains('Statistics delivery rejected')));
        } else {
          expect(
            text,
            contains('Statistics delivery rejected, status $status'),
          );
        }
        expect(text, isNot(contains('secret-response-body')));
        expect(text, isNot(contains('${server.port}')));
        expect(text, isNot(contains('public')));
        expect(text, isNot(contains('bull.installation.active')));

        // The wallet path is not blocked: a later observation still goes out.
        transport.installationActive(DateTime.utc(2026, 11, 26));
        await transport.flush().timeout(const Duration(seconds: 5));
        expect(received, 2);
      });
    }
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
      'mainnet',
      () async => true,
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
