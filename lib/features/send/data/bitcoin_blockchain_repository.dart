import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';

/// Thin repository over [BdkBitcoinBlockchainDatasource]. Its only job is to
/// route broadcast operations through [ElectrumServersPort.runWithFallback]
/// so callers cannot fetch a server list themselves — the privacy / fallback
/// rule lives in one place.
class BitcoinBlockchainRepository {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _serversPort;

  const BitcoinBlockchainRepository({
    required BdkBitcoinBlockchainDatasource blockchainDatasource,
    required this._serversPort,
  }) : _blockchain = blockchainDatasource;

  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    Network? network,
    bool? isTestnet,
  }) {
    if (network != null && isTestnet != null) {
      throw ArgumentError('Supply exactly one network representation');
    }
    network ??= Network.fromEnvironment(isTestnet: isTestnet, isLiquid: false);
    return _serversPort.runWithFallback<String>(
      network: switch (network) {
        Network.bitcoinMainnet => ElectrumServerNetwork.bitcoinMainnet,
        Network.bitcoinTestnet => ElectrumServerNetwork.bitcoinTestnet,
        Network.bitcoinRegtest => ElectrumServerNetwork.bitcoinRegtest,
        _ => throw const UnsupportedNetworkException(),
      },
      operation: (connection) =>
          _blockchain.broadcastPsbt(finalizedPsbt, connection: connection),
    );
  }

  Future<String> broadcastTransaction(
    List<int> transaction, {
    Network? network,
    bool? isTestnet,
  }) {
    if (network != null && isTestnet != null) {
      throw ArgumentError('Supply exactly one network representation');
    }
    network ??= Network.fromEnvironment(isTestnet: isTestnet, isLiquid: false);
    return _serversPort.runWithFallback<String>(
      network: switch (network) {
        Network.bitcoinMainnet => ElectrumServerNetwork.bitcoinMainnet,
        Network.bitcoinTestnet => ElectrumServerNetwork.bitcoinTestnet,
        Network.bitcoinRegtest => ElectrumServerNetwork.bitcoinRegtest,
        _ => throw const UnsupportedNetworkException(),
      },
      operation: (connection) => _blockchain.broadcastTransaction(
        Uint8List.fromList(transaction),
        connection: connection,
      ),
    );
  }
}
