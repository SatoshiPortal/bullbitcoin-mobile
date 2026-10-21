import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/exchange/data/datasources/exchange_notification_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_api_key_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'disconnect during credential read prevents a late connection',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requests = 0;
      final subscription = server.listen((request) {
        requests++;
        unawaited(request.response.close());
      });
      final credential = Completer<Result<String?, ExchangeApiKeyFailure>>();
      final datasource = ExchangeNotificationDatasource(
        baseUrl: 'http://127.0.0.1:${server.port}',
        readApiKey: () => credential.future,
      );
      addTearDown(() async {
        datasource.dispose();
        await subscription.cancel();
        await server.close(force: true);
      });
      final pending = datasource.connect();
      datasource.disconnect();
      credential.complete(const Ok('synthetic'));
      await pending;
      expect(requests, 0);
      expect(datasource.isConnected, isFalse);
    },
  );

  test('each real handshake reads the latest credential', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final keys = <String?>[];
    final sockets = <WebSocket>[];
    final subscription = server.listen((request) async {
      keys.add(request.headers.value('X-API-Key'));
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
    });
    String? key = 'first';
    final datasource = ExchangeNotificationDatasource(
      baseUrl: 'http://127.0.0.1:${server.port}',
      readApiKey: () async => Ok(key),
    );
    addTearDown(() async {
      datasource.dispose();
      for (final socket in sockets) {
        await socket.close();
      }
      await subscription.cancel();
      await server.close(force: true);
    });
    await datasource.connect();
    expect(datasource.isConnected, isTrue);
    datasource.disconnect();
    key = 'replacement';
    await datasource.connect();
    expect(datasource.isConnected, isTrue);
    datasource.disconnect();
    key = null;
    await datasource.connect();
    expect(datasource.isConnected, isFalse);
    expect(keys, ['first', 'replacement']);
  });

  test('storage errors retry but logout cancels further attempts', () {
    fakeAsync((time) {
      var reads = 0;
      var available = false;
      final datasource = ExchangeNotificationDatasource(
        baseUrl: 'https://example.invalid',
        readApiKey: () async {
          reads++;
          return available
              ? const Ok(null)
              : const Err(ExchangeApiKeyReadFailure());
        },
      );
      unawaited(datasource.connect());
      time.flushMicrotasks();
      expect(reads, 1);
      time.elapse(const Duration(seconds: 5));
      expect(reads, 2);
      available = true;
      time.elapse(const Duration(seconds: 5));
      expect(reads, 3);
      time.elapse(const Duration(seconds: 30));
      expect(reads, 3);
      datasource.dispose();
      time.flushMicrotasks();
      expect(time.nonPeriodicTimerCount, 0);
    });
  });
}
