import 'dart:io';

import 'package:bb_mobile/core/electrum/adapters/server_status_adapter.dart';
import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'self_signed_electrum_server.dart';

/// The probe must accept exactly the certificates the BDK/LWK sync accepts,
/// so that "online" here means the wallet can really use the server.
void main() {
  final adapter = ServerStatusAdapter(const ElectrumSocketConnector());
  const network = ElectrumServerNetwork.liquidMainnet;

  late SelfSignedElectrumServer fixture;

  setUpAll(() async => fixture = await SelfSignedElectrumServer.create());
  tearDownAll(() => fixture.dispose());

  Future<SecureServerSocket> startServer() async {
    final server = await SecureServerSocket.bind(
      '127.0.0.1',
      0,
      fixture.securityContext,
    );
    serveElectrumStub(server);
    return server;
  }

  test('validateDomain false accepts a self-signed certificate', () async {
    final server = await startServer();
    addTearDown(server.close);

    final status = await adapter.checkElectrum(
      url: 'ssl://127.0.0.1:${server.port}',
      network: network,
      validateDomain: false,
      timeout: 10,
    );

    expect(status, ElectrumServerStatus.online);
  });

  test('validateDomain true rejects a self-signed certificate', () async {
    final server = await startServer();
    addTearDown(server.close);

    final status = await adapter.checkElectrum(
      url: 'ssl://127.0.0.1:${server.port}',
      network: network,
      validateDomain: true,
      timeout: 10,
    );

    expect(status, ElectrumServerStatus.offline);
  });

  test('a tcp:// server is probed in the clear, whatever the flag', () async {
    final server = await ServerSocket.bind('127.0.0.1', 0);
    addTearDown(server.close);
    serveElectrumStub(server);

    final status = await adapter.checkElectrum(
      url: 'tcp://127.0.0.1:${server.port}',
      network: network,
      validateDomain: true,
      timeout: 10,
    );

    expect(status, ElectrumServerStatus.online);
  });

  test('Bitcoin uses BDK with the resolved production configuration', () async {
    String? probedUrl;
    String? probedSocks5;
    int? probedTimeout;
    int? probedRetry;
    bool? probedValidateDomain;
    bool? probedIsMainnet;
    final adapter = ServerStatusAdapter(
      const ElectrumSocketConnector(),
      bdkProbe:
          ({
            required url,
            required socks5,
            required timeout,
            required retry,
            required validateDomain,
            required isMainnet,
          }) async {
            probedUrl = url;
            probedSocks5 = socks5;
            probedTimeout = timeout;
            probedRetry = retry;
            probedValidateDomain = validateDomain;
            probedIsMainnet = isMainnet;
          },
    );

    final status = await adapter.checkElectrum(
      url: 'ssl://hidden.onion:50002',
      network: ElectrumServerNetwork.bitcoinMainnet,
      validateDomain: false,
      timeout: 5,
      retry: 3,
      proxyEndpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41001),
    );

    expect(status, ElectrumServerStatus.online);
    expect(probedUrl, 'ssl://hidden.onion:50002');
    expect(probedSocks5, '127.0.0.1:41001');
    expect(probedTimeout, 30);
    expect(probedRetry, 3);
    expect(probedValidateDomain, isFalse);
    expect(probedIsMainnet, isTrue);
  });

  test('Bitcoin reports a failed BDK probe as offline', () async {
    final adapter = ServerStatusAdapter(
      const ElectrumSocketConnector(),
      bdkProbe:
          ({
            required url,
            required socks5,
            required timeout,
            required retry,
            required validateDomain,
            required isMainnet,
          }) async => throw const SocketException('probe failed'),
    );

    final status = await adapter.checkElectrum(
      url: 'ssl://bitcoin.example.com:50002',
      network: ElectrumServerNetwork.bitcoinMainnet,
      validateDomain: true,
      timeout: 5,
      retry: 1,
    );

    expect(status, ElectrumServerStatus.offline);
  });
}
