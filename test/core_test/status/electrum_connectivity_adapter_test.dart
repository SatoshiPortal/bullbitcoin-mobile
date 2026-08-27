import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/status/interface_adapters/adapter/electrum_connectivity_adapter.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_tor/tor.dart';

void main() {
  test('checks an onion server through its resolved embedded route', () async {
    final serversPort = _FakeElectrumServersPort(
      _connection(socks5: '127.0.0.1:41001'),
    );
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final adapter = ElectrumConnectivityAdapter(
      electrumServersPort: serversPort,
      serverStatusPort: statusPort,
    );

    final online = await adapter.checkServersInUseAreOnlineForNetwork(
      Network.bitcoinMainnet,
    );

    expect(online, isTrue);
    expect(serversPort.network, ElectrumServerNetwork.bitcoinMainnet);
    expect(statusPort.proxyEndpoint?.authority, '127.0.0.1:41001');
    // Null, so the port applies its longer onion default. Passing the user's 5s
    // clearnet ceiling here made healthy onion servers report offline and lit
    // the Tor error banner.
    expect(statusPort.timeout, isNull);
  });

  test('an unproxied server keeps the user timeout', () async {
    final serversPort = _FakeElectrumServersPort(_connection());
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final adapter = ElectrumConnectivityAdapter(
      electrumServersPort: serversPort,
      serverStatusPort: statusPort,
    );

    await adapter.checkServersInUseAreOnlineForNetwork(Network.bitcoinMainnet);

    expect(statusPort.timeout, 5);
  });

  test('an empty proxy string means no proxy, not a malformed one', () async {
    final serversPort = _FakeElectrumServersPort(_connection(socks5: '  '));
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final adapter = ElectrumConnectivityAdapter(
      electrumServersPort: serversPort,
      serverStatusPort: statusPort,
    );

    final online = await adapter.checkServersInUseAreOnlineForNetwork(
      Network.bitcoinMainnet,
    );

    expect(online, isTrue);
    expect(statusPort.proxyEndpoint, isNull);
  });

  test('does not bypass a malformed configured proxy', () async {
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final adapter = ElectrumConnectivityAdapter(
      electrumServersPort: _FakeElectrumServersPort(
        _connection(socks5: 'not-an-endpoint'),
      ),
      serverStatusPort: statusPort,
    );

    final online = await adapter.checkServersInUseAreOnlineForNetwork(
      Network.bitcoinMainnet,
    );

    expect(online, isFalse);
    expect(statusPort.calls, 0);
  });

  test('reports an unreachable active server set as offline', () async {
    final adapter = ElectrumConnectivityAdapter(
      electrumServersPort: _FakeElectrumServersPort(_connection()),
      serverStatusPort: _FakeServerStatusPort(ElectrumServerStatus.offline),
    );

    expect(
      await adapter.checkServersInUseAreOnlineForNetwork(
        Network.bitcoinMainnet,
      ),
      isFalse,
    );
  });
}

/// The seeded default for `timeout` is 5 seconds, so the fixture uses it: a
/// proxied probe must not inherit that clearnet ceiling.
ElectrumConnection _connection({String? socks5, int timeout = 5}) =>
    ElectrumConnection(
      url: 'ssl://hiddenservice.onion:50002',
      retry: 1,
      timeout: timeout,
      stopGap: 20,
      validateDomain: true,
      isCustom: false,
      socks5: socks5,
    );

final class _FakeElectrumServersPort implements ElectrumServersPort {
  final ElectrumConnection connection;
  ElectrumServerNetwork? network;

  _FakeElectrumServersPort(this.connection);

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    this.network = network;
    return operation(connection);
  }
}

final class _FakeServerStatusPort implements ServerStatusPort {
  final ElectrumServerStatus result;
  TorProxyEndpoint? proxyEndpoint;
  int? timeout;
  bool? validateDomain;
  int calls = 0;

  _FakeServerStatusPort(this.result);

  @override
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    required bool validateDomain,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  }) async {
    calls++;
    this.timeout = timeout;
    this.proxyEndpoint = proxyEndpoint;
    this.validateDomain = validateDomain;
    return result;
  }

  @override
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  }) => throw UnimplementedError();
}
