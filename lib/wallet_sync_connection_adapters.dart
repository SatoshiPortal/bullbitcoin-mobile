import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:wallet/wallet.dart';

final class WalletSyncConnectionAdapter implements WalletSyncConnectionPort {
  final ElectrumServersPort _servers;

  const WalletSyncConnectionAdapter(this._servers);

  @override
  Future<T> runWithFallback<T>({
    required Network network,
    required Future<T> Function(WalletConnectionPort connection) operation,
  }) => _servers.runWithFallback(
    network: ElectrumServerNetwork.fromEnvironment(
      isTestnet: network.isTestnet,
      isLiquid: network.isLiquid,
    ),
    operation: (connection) => operation(_ElectrumWalletConnection(connection)),
  );

  @override
  String? failureCategory(Object error) => switch (error) {
    NoElectrumServersConfiguredException() => 'no_servers',
    OnionServerWithoutTorException() => 'onion_without_tor',
    ClearnetServerWithoutConfiguredTorException() =>
      'clearnet_without_configured_tor',
    AllElectrumServersFailedException(:final triedCustomServers) =>
      triedCustomServers ? 'custom_servers_failed' : 'default_servers_failed',
    _ => null,
  };
}

/// Hands the wallet package the resolved values of one Electrum attempt.
final class _ElectrumWalletConnection implements WalletConnectionPort {
  final ElectrumConnection _connection;

  const _ElectrumWalletConnection(this._connection);

  @override
  String get url => _connection.url;

  @override
  int get retry => _connection.retry;

  @override
  int get effectiveTimeout => _connection.effectiveTimeout;

  @override
  int get stopGap => _connection.stopGap;

  @override
  bool get validateDomain => _connection.validateDomain;

  @override
  String? get socks5 => _connection.socks5;
}
