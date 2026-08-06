import 'dart:io';

import 'package:bb_mobile/core/electrum/adapters/server_status_adapter.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:flutter_test/flutter_test.dart';

import 'self_signed_electrum_server.dart';

/// The probe must accept exactly the certificates the BDK/LWK sync accepts,
/// so that "online" here means the wallet can really use the server.
void main() {
  const adapter = ServerStatusAdapter();
  const network = ElectrumServerNetwork.bitcoinMainnet;

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
}
