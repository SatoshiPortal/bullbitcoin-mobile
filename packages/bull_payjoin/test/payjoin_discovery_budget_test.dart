import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_payjoin/src/engine/payjoin_logger.dart';
import 'package:bull_payjoin/src/engine/pdk_payjoin_datasource.dart';
import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:payjoin/payjoin.dart' as pdk;
import 'package:test/test.dart';

// Public OHTTP key configuration from payjoin-test-utils.
const _ohttpKeys =
    'AQAWBFJz2qj2TN+Ajx6UA5gJ9kf8Icposr0x5zCpxX3zaISy54JuL6GtK58jiBV2WqZ7H1bMcsZpg0BpiYaHgO5Zmx8ABAABAAM=';

void main() {
  test('each HTTP stage is bounded by the remaining discovery budget', () {
    fakeAsync((clock) {
      final stageTimeouts = <Duration>[];
      final dio = Dio();
      final datasource = PdkPayjoinDatasource(
        dio: dio,
        log: PayjoinLogger.silent,
        ohttpKeysFetcher:
            ({
              required ohttpRelayUrl,
              required directoryUrl,
              required timeout,
            }) async {
              stageTimeouts.add(timeout);
              throw const HttpException('unreachable');
            },
      );
      datasource.fetchDirectoryKeys(timeout: const Duration(seconds: 9));
      clock.flushMicrotasks();
      expect(stageTimeouts, isNotEmpty);
      for (final stageTimeout in stageTimeouts) {
        expect(stageTimeout, greaterThan(Duration.zero));
        expect(stageTimeout, lessThanOrEqualTo(const Duration(seconds: 3)));
      }
      datasource.dispose();
      clock.flushMicrotasks();
      dio.close(force: true);
    });
  });

  test('directory discovery releases the receiver after thirty seconds', () {
    fakeAsync((clock) {
      var attempts = 0;
      var completed = false;
      final dio = Dio();
      final datasource = PdkPayjoinDatasource(
        dio: dio,
        log: PayjoinLogger.silent,
        ohttpKeysFetcher:
            ({
              required ohttpRelayUrl,
              required directoryUrl,
              required timeout,
            }) async {
              attempts++;
              await Future<void>.delayed(const Duration(seconds: 10));
              throw const HttpException('simulated timeout');
            },
      );
      datasource.fetchDirectoryKeys().then((result) {
        expect(result, isNull);
        completed = true;
      });

      clock.elapse(const Duration(seconds: 29));
      expect(completed, isFalse);
      clock.elapse(const Duration(seconds: 1));
      expect(completed, isTrue);
      final attemptsAtDeadline = attempts;
      clock.elapse(const Duration(minutes: 3));
      expect(attempts, attemptsAtDeadline, reason: 'no background retry loop');
      datasource.dispose();
      clock.flushMicrotasks();
      dio.close(force: true);
    });
  });

  test('a late key response cannot restart discovery after the deadline', () {
    fakeAsync((clock) {
      final pending = Completer<pdk.OhttpKeys>();
      var attempts = 0;
      var completed = false;
      final dio = Dio();
      final datasource = PdkPayjoinDatasource(
        dio: dio,
        log: PayjoinLogger.silent,
        ohttpKeysFetcher:
            ({
              required ohttpRelayUrl,
              required directoryUrl,
              required timeout,
            }) {
              attempts++;
              return pending.future;
            },
      );
      datasource.fetchDirectoryKeys().then((result) {
        expect(result, isNull);
        completed = true;
      });

      clock.elapse(const Duration(seconds: 30));
      expect(completed, isTrue);
      pending.complete(pdk.OhttpKeys.decode(bytes: base64Decode(_ohttpKeys)));
      clock.flushMicrotasks();
      clock.elapse(const Duration(minutes: 1));
      expect(attempts, 1);
      datasource.dispose();
      clock.flushMicrotasks();
      dio.close(force: true);
    });
  });
}
