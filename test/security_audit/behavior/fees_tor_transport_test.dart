import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/fees/data/fees_repository_impl.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_server_repository.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bull_tor/tor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MempoolSettings extends Mock implements MempoolSettingsRepository {}

class _MempoolServers extends Mock implements MempoolServerRepository {}

class _GlobalSettings extends Mock implements SettingsRepository {}

class _MockTor extends Mock implements Tor {}

class _MockEmbeddedTor extends Mock implements EmbeddedTor {}

class _MockExternalTor extends Mock implements ExternalTor {}

class _MockTorSessions extends Mock implements TorSessions {}

class _Socks5Proxy {
  final ServerSocket _server;
  int connections = 0;

  _Socks5Proxy(this._server);

  int get port => _server.port;

  static Future<_Socks5Proxy> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final proxy = _Socks5Proxy(server);
    server.listen(proxy._handleClient);
    return proxy;
  }

  Future<void> close() => _server.close();

  void _handleClient(Socket client) {
    connections++;
    final buffer = <int>[];
    var greeted = false;
    var connected = false;
    Socket? upstream;

    client.listen(
      (chunk) async {
        if (connected) {
          upstream?.add(chunk);
          return;
        }
        buffer.addAll(chunk);

        if (!greeted) {
          if (buffer.length < 2) return;
          final methodCount = buffer[1];
          if (buffer.length < 2 + methodCount) return;
          buffer.removeRange(0, 2 + methodCount);
          client.add(const [0x05, 0x00]);
          greeted = true;
        }

        if (buffer.length < 5) return;
        final addressType = buffer[3];
        String host;
        int destinationPort;
        int consumed;
        if (addressType == 0x01) {
          if (buffer.length < 10) return;
          host = buffer.sublist(4, 8).join('.');
          destinationPort = (buffer[8] << 8) | buffer[9];
          consumed = 10;
        } else if (addressType == 0x03) {
          final length = buffer[4];
          if (buffer.length < 5 + length + 2) return;
          host = utf8.decode(buffer.sublist(5, 5 + length));
          destinationPort = (buffer[5 + length] << 8) | buffer[6 + length];
          consumed = 7 + length;
        } else {
          client.destroy();
          return;
        }

        buffer.removeRange(0, consumed);
        final destinationHost =
            host.endsWith('.invalid') || host.endsWith('.onion')
            ? InternetAddress.loopbackIPv4.address
            : host;
        upstream = await Socket.connect(destinationHost, destinationPort);
        connected = true;
        client.add(const [0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0]);
        upstream!.listen(
          client.add,
          onDone: client.destroy,
          onError: (_) => client.destroy(),
        );
        if (buffer.isNotEmpty) {
          upstream!.add(List<int>.of(buffer));
          buffer.clear();
        }
      },
      onDone: () => upstream?.destroy(),
      onError: (_) => upstream?.destroy(),
    );
  }
}

SettingsEntity _settings({
  required bool useTorProxy,
  required int torProxyPort,
}) => SettingsEntity(
  environment: Environment.mainnet,
  bitcoinUnit: BitcoinUnit.sats,
  currencyCode: 'USD',
  useTorProxy: useTorProxy,
  torProxyPort: torProxyPort,
);

void main() {
  late HttpServer oracle;
  late int oracleHits;
  late MempoolServerNetwork network;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() async {
    oracleHits = 0;
    network = MempoolServerNetwork.fromEnvironment(
      isTestnet: false,
      isLiquid: false,
    );
    oracle = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    oracle.listen((request) {
      oracleHits++;
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'fastestFee': 5,
            'halfHourFee': 4,
            'hourFee': 3,
            'economyFee': 2,
            'minimumFee': 1,
          }),
        )
        ..close();
    });
  });

  tearDown(() => oracle.close(force: true));

  FeesRepositoryImpl buildRepository({
    required String serverUrl,
    required bool useTorProxy,
    required int torProxyPort,
    required Tor tor,
  }) {
    final globalSettings = _GlobalSettings();
    final mempoolSettings = _MempoolSettings();
    final mempoolServers = _MempoolServers();
    final server = MempoolServer.existing(
      url: serverUrl,
      network: network,
      isCustom: true,
      enableSsl: false,
    );

    when(() => globalSettings.fetch()).thenAnswer(
      (_) async =>
          _settings(useTorProxy: useTorProxy, torProxyPort: torProxyPort),
    );
    when(() => mempoolSettings.fetchByNetwork(network)).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(network: network, useForFeeEstimation: true),
      ),
    );
    when(
      () => mempoolServers.fetchCustomServer(network),
    ).thenAnswer((_) async => Ok(server));

    return FeesRepositoryImpl(
      feesDatasource: FeesDatasource(
        dioBuilder: (baseUrl) => Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 2),
            sendTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 2),
            followRedirects: false,
            validateStatus: (status) => status == 200,
          ),
        ),
      ),
      mempoolSettingsRepository: mempoolSettings,
      mempoolServerRepository: mempoolServers,
      settingsRepository: globalSettings,
      tor: tor,
    );
  }

  test('never tries direct HTTP when the external proxy path fails', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closedProxyPort = probe.port;
    await probe.close();
    final endpoint = TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: closedProxyPort,
    );
    final tor = _MockTor();
    final external = _MockExternalTor();
    when(() => tor.external).thenReturn(external);
    when(() => external.verify(endpoint)).thenAnswer(
      (_) async => TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      ),
    );
    final repository = buildRepository(
      serverUrl: '${oracle.address.address}:${oracle.port}',
      useTorProxy: true,
      torProxyPort: closedProxyPort,
      tor: tor,
    );

    await expectLater(
      repository.getNetworkFees(network: Network.bitcoinMainnet),
      throwsA(isA<MempoolFeesException>()),
    );

    expect(
      oracleHits,
      0,
      reason: 'an enabled external proxy must never fall back to direct HTTP',
    );
  });

  test('fetches fees through a configured external SOCKS5 proxy', () async {
    final proxy = await _Socks5Proxy.start();
    addTearDown(proxy.close);
    final endpoint = TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: proxy.port,
    );
    final tor = _MockTor();
    final external = _MockExternalTor();
    when(() => tor.external).thenReturn(external);
    when(() => external.verify(endpoint)).thenAnswer(
      (_) async => TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      ),
    );
    final repository = buildRepository(
      serverUrl: 'fees.invalid:${oracle.port}',
      useTorProxy: true,
      torProxyPort: proxy.port,
      tor: tor,
    );

    final fees = await repository.getNetworkFees(
      network: Network.bitcoinMainnet,
    );

    expect(fees.fastest.value, 5);
    expect(proxy.connections, greaterThan(0));
    expect(oracleHits, greaterThan(0));
  });

  test('retries failed direct fee traffic through embedded Tor', () async {
    final proxy = await _Socks5Proxy.start();
    addTearDown(proxy.close);
    final endpoint = TorProxyEndpoint(
      host: InternetAddress.loopbackIPv4.address,
      port: proxy.port,
    );
    var sessionClosed = false;
    final tor = _MockTor();
    final embedded = _MockEmbeddedTor();
    final sessions = _MockTorSessions();
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.sessions).thenReturn(sessions);
    when(() => sessions.open()).thenAnswer(
      (_) async => TorSession(
        endpoint,
        TorTransport.direct,
        () async => sessionClosed = true,
      ),
    );
    final repository = buildRepository(
      serverUrl: 'fees.invalid:${oracle.port}',
      useTorProxy: false,
      torProxyPort: 9050,
      tor: tor,
    );

    final fees = await repository.getNetworkFees(
      network: Network.bitcoinMainnet,
    );

    expect(fees.fastest.value, 5);
    expect(proxy.connections, greaterThan(0));
    expect(oracleHits, greaterThan(0));
    expect(sessionClosed, isTrue);
  });
}
