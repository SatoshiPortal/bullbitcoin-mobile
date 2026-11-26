import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bull_reporting/src/metrics/daily_active.dart';
import 'package:bull_reporting/src/metrics/statistics_network.dart';
import 'package:bull_reporting/src/metrics/statistics_runtime.dart';
import 'package:bull_reporting/src/metrics/statistics_transport.dart';
import 'package:flutter_test/flutter_test.dart';

final class FakeNetwork implements StatisticsNetwork {
  final controller = StreamController<bool>.broadcast(sync: true);
  bool? mainnet;
  Completer<bool>? readGate;

  @override
  Stream<bool> get changes => controller.stream;

  @override
  Future<bool> isMainnet() async {
    final gate = readGate;
    if (gate != null) return gate.future;
    return mainnet ?? false;
  }

  void change(bool? value) {
    controller.add(true);
    mainnet = value;
    controller.add(false);
  }
}

final class MemoryMarker implements ActiveDayStore {
  String? day;

  @override
  Future<String?> read() async => day;

  @override
  Future<void> write(String value) async => day = value;
}

void main() {
  late HttpServer server;
  late List<String> requests;
  late FakeNetwork network;
  late MemoryMarker store;
  late StatisticsTransport transport;
  late StatisticsRuntime runtime;

  Future<void> settle() async {
    await Future<void>.delayed(Duration.zero);
    await runtime.idle;
    await Future<void>.delayed(Duration.zero);
  }

  void start({required bool releaseMode}) {
    runtime = StatisticsRuntime(network, transport, store, releaseMode);
    runtime.setForeground(true);
    runtime.setConsent(true);
  }

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    server.listen((request) async {
      requests.add(await utf8.decoder.bind(request).join());
      await request.response.close();
    });
    network = FakeNetwork();
    store = MemoryMarker();
    transport = StatisticsTransport(
      'http://public@127.0.0.1:${server.port}/1',
      '1+1',
      'mainnet',
      () => runtime.canSend(),
    );
  });

  tearDown(() async {
    runtime.dispose();
    await network.controller.close();
    await server.close(force: true);
  });

  test('debug never emits even on mainnet', () async {
    network.mainnet = true;
    start(releaseMode: false);
    await settle();
    await transport.flush();
    expect(store.day, isNull);
    expect(requests, isEmpty);
  });

  test('unknown and non-mainnet deny, then mainnet permits', () async {
    start(releaseMode: true);
    await settle();
    expect(store.day, isNull);
    network.change(false);
    await settle();
    expect(store.day, isNull);
    network.change(true);
    await settle();
    await transport.flush();
    expect(store.day, isNotNull);
    expect(requests, hasLength(1));
    expect(requests.single, contains('"value":"mainnet"'));
  });

  test('switching away discards queued work before switching back', () async {
    network.mainnet = true;
    start(releaseMode: true);
    await settle();
    expect(store.day, isNotNull);
    network.change(false);
    await settle();
    network.change(true);
    await settle();
    await transport.flush();
    expect(requests, isEmpty);
  });

  test('send rechecks network even without a change notification', () async {
    network.mainnet = true;
    start(releaseMode: true);
    await settle();
    network.mainnet = false;
    await transport.flush();
    expect(requests, isEmpty);
  });

  test('a stale mainnet read cannot reopen the gate after a switch', () async {
    final gate = Completer<bool>();
    network.readGate = gate;
    start(releaseMode: true);
    await Future<void>.delayed(Duration.zero);
    network.readGate = null;
    network.change(false);
    gate.complete(true);
    await settle();
    await transport.flush();
    expect(store.day, isNull);
    expect(requests, isEmpty);
  });

  test('switching away closes a request awaiting a response', () async {
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
        // A network transition may close the connection.
      }
    });
    transport = StatisticsTransport(
      'http://public@127.0.0.1:${server.port}/1',
      '1+1',
      'mainnet',
      () => runtime.canSend(),
    );
    network.mainnet = true;
    start(releaseMode: true);
    await settle();
    final sending = transport.flush();
    await received.future;
    network.change(false);
    await sending.timeout(const Duration(seconds: 3));
    finish.complete();
    expect(await runtime.canSend(), isFalse);
  });
}
