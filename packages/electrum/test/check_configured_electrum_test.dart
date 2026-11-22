import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:electrum/src/domain/electrum_fallback_runner.dart';
import 'package:electrum/src/domain/ports/server_status_port.dart';
import 'package:electrum/src/domain/usecases/check_configured_electrum_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_tor/tor.dart';

void main() {
  test('checks an onion server through its resolved embedded route', () async {
    final serversPort = _FakeElectrumServersPort(
      _connection(socks5: '127.0.0.1:41001'),
    );
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final online = await checkConfiguredElectrum(
      serversPort,
      statusPort,
      ElectrumServerNetwork.bitcoinMainnet,
    );

    expect(online, isA<Ok<ElectrumServerStatus, ElectrumFailure>>());
    expect(serversPort.network, ElectrumServerNetwork.bitcoinMainnet);
    expect(statusPort.proxyEndpoint?.authority, '127.0.0.1:41001');
    expect(statusPort.timeout, ElectrumConnection.onionMinimumTimeout);
    expect(statusPort.retry, 1);
  });

  test('an unproxied server keeps the user timeout', () async {
    final serversPort = _FakeElectrumServersPort(
      _connection(url: 'ssl://electrum.example.com:50002'),
    );
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    await checkConfiguredElectrum(
      serversPort,
      statusPort,
      ElectrumServerNetwork.bitcoinMainnet,
    );

    expect(statusPort.timeout, 5);
  });

  test('an empty proxy string means no proxy, not a malformed one', () async {
    final serversPort = _FakeElectrumServersPort(_connection(socks5: '  '));
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final online = await checkConfiguredElectrum(
      serversPort,
      statusPort,
      ElectrumServerNetwork.bitcoinMainnet,
    );

    expect(online, isA<Ok<ElectrumServerStatus, ElectrumFailure>>());
    expect(statusPort.proxyEndpoint, isNull);
  });

  test('does not bypass a malformed configured proxy', () async {
    final statusPort = _FakeServerStatusPort(ElectrumServerStatus.online);
    final online = await checkConfiguredElectrum(
      _FakeElectrumServersPort(_connection(socks5: 'not-an-endpoint')),
      statusPort,
      ElectrumServerNetwork.bitcoinMainnet,
    );

    expect(online, isA<Err<ElectrumServerStatus, ElectrumFailure>>());
    expect(statusPort.calls, 0);
  });

  test(
    'tries the next configured endpoint when the first is offline',
    () async {
      final first = _connection(url: 'ssl://first.example:50002');
      final second = _connection(url: 'ssl://second.example:50002');
      final status = _FakeServerStatusPort(
        ElectrumServerStatus.online,
        offlineUrl: first.url,
      );

      final result = await checkConfiguredElectrum(
        _FakeElectrumServersPort(first, fallback: [second]),
        status,
        ElectrumServerNetwork.bitcoinMainnet,
      );
      expect(result, isA<Ok<ElectrumServerStatus, ElectrumFailure>>());
      expect(status.checked, [first.url, second.url]);
    },
  );

  test('reports an unreachable active server set as offline', () async {
    expect(
      await checkConfiguredElectrum(
        _FakeElectrumServersPort(_connection()),
        _FakeServerStatusPort(ElectrumServerStatus.offline),
        ElectrumServerNetwork.bitcoinMainnet,
      ),
      isA<Err<ElectrumServerStatus, ElectrumFailure>>(),
    );
  });
}

/// The seeded default for `timeout` is 5 seconds, so the fixture uses it: a
/// proxied probe must not inherit that clearnet ceiling.
ElectrumConnection _connection({
  String url = 'ssl://hiddenservice.onion:50002',
  String? socks5,
  int timeout = 5,
}) => ElectrumConnection(
  url: url,
  retry: 1,
  timeout: timeout,
  stopGap: 20,
  validateDomain: true,
  isCustom: false,
  socks5: socks5,
);

final class _FakeElectrumServersPort implements ElectrumServersPort {
  @override
  Future<bool> hasCustomServers({
    required ElectrumServerNetwork network,
  }) async => false;

  final ElectrumConnection connection;
  final List<ElectrumConnection> fallback;
  ElectrumServerNetwork? network;

  _FakeElectrumServersPort(this.connection, {this.fallback = const []});

  @override
  Future<T> runWithFallback<T>({
    required ElectrumServerNetwork network,
    required Future<T> Function(ElectrumConnection connection) operation,
    bool Function(Object error)? isTransient,
  }) {
    this.network = network;
    return runElectrumFallback(
      servers: [connection, ...fallback],
      urlOf: (server) => server.url,
      isCustomOf: (server) => server.isCustom,
      operation: operation,
      isTransient: isTransient,
    );
  }
}

final class _FakeServerStatusPort implements ServerStatusPort {
  final ElectrumServerStatus result;
  TorProxyEndpoint? proxyEndpoint;
  int? timeout;
  bool? validateDomain;
  int? retry;
  final List<String> checked = [];
  final String? offlineUrl;

  int get calls => checked.length;

  _FakeServerStatusPort(this.result, {this.offlineUrl});

  @override
  Future<ElectrumServerStatus> checkElectrum({
    required String url,
    required ElectrumServerNetwork network,
    required bool validateDomain,
    int? timeout,
    int? retry,
    TorProxyEndpoint? proxyEndpoint,
  }) async {
    checked.add(url);
    this.timeout = timeout;
    this.retry = retry;
    this.proxyEndpoint = proxyEndpoint;
    this.validateDomain = validateDomain;
    return url == offlineUrl ? ElectrumServerStatus.offline : result;
  }

  @override
  Future<ElectrumServerStatus> checkSocket({
    required String url,
    int? timeout,
    TorProxyEndpoint? proxyEndpoint,
  }) => throw UnimplementedError();
}
