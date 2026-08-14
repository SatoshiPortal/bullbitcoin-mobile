// Behavioral proof for the audit finding on the fee datasource Tor transport
// (issue #2658 fix).
//
// `fix(fees)` configures Tor by assigning `'SOCKS5 host:port'` to
// `HttpClient.findProxy`. dart:io only understands the browser PAC vocabulary
// (`DIRECT`, `PROXY host:port`), so this string is not a usable proxy
// directive. The second test runs a real SOCKS5 proxy in front of the fee
// oracle: a Tor-aware client must succeed through it.
import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/fees/data/fees_datasource.dart';
import 'package:bb_mobile/core/mempool/application/usecases/get_active_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/repositories/mempool_settings_repository.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockMempoolSettingsRepository extends Mock
    implements MempoolSettingsRepository {}

class _MockActiveServerUsecase extends Mock
    implements GetActiveMempoolServerUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

/// Minimal SOCKS5 CONNECT proxy: enough to prove whether the HTTP client
/// actually speaks SOCKS5 to the configured port.
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
        upstream = await Socket.connect(host, destinationPort);
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

void main() {
  late HttpServer feeServer;
  late int directHits;

  setUpAll(() {
    registerFallbackValue(
      MempoolServerNetwork.fromEnvironment(isTestnet: false, isLiquid: false),
    );
  });

  setUp(() async {
    directHits = 0;
    feeServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    feeServer.listen((request) async {
      directHits++;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'fastestFee': 4,
            'halfHourFee': 3,
            'hourFee': 2,
            'economyFee': 1,
            'minimumFee': 1,
          }),
        );
      await request.response.close();
    });
  });

  tearDown(() async {
    await feeServer.close(force: true);
  });

  FeesDatasource buildDatasource({required int torPort}) {
    final settingsRepository = _MockSettingsRepository();
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'CAD',
        useTorProxy: true,
        torProxyPort: torPort,
      ),
    );

    final mempoolSettings = _MockMempoolSettingsRepository();
    when(() => mempoolSettings.fetchByNetwork(any())).thenAnswer(
      (_) async => Ok(
        MempoolSettings.existing(
          network: MempoolServerNetwork.fromEnvironment(
            isTestnet: false,
            isLiquid: false,
          ),
          useForFeeEstimation: false,
        ),
      ),
    );

    return FeesDatasource(
      getActiveMempoolServerUsecase: _MockActiveServerUsecase(),
      mempoolSettingsRepository: mempoolSettings,
      settingsRepository: settingsRepository,
      dioBuilder: (_) => Dio(
        BaseOptions(
          baseUrl: 'http://${feeServer.address.address}:${feeServer.port}',
          connectTimeout: const Duration(seconds: 2),
          receiveTimeout: const Duration(seconds: 2),
          followRedirects: false,
          validateStatus: (status) => status == 200,
        ),
      ),
    );
  }

  test('fee fetch fails closed when the Tor proxy is unreachable', () async {
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final closedPort = probe.port;
    await probe.close();

    final datasource = buildDatasource(torPort: closedPort);

    await expectLater(
      datasource.fetchBitcoinNetworkFees(isTestnet: false),
      throwsA(anything),
    );
    expect(
      directHits,
      0,
      reason: 'no fee request may bypass the configured proxy',
    );
  });

  test('fee fetch succeeds through a running SOCKS5 proxy', () async {
    final proxy = await _Socks5Proxy.start();
    addTearDown(proxy.close);

    final datasource = buildDatasource(torPort: proxy.port);

    final fees = await datasource.fetchBitcoinNetworkFees(isTestnet: false);

    expect(fees.fastestFee, 4);
    expect(
      proxy.connections,
      greaterThan(0),
      reason: 'the Tor setting must route fee traffic through the SOCKS5 proxy',
    );
  });
}
