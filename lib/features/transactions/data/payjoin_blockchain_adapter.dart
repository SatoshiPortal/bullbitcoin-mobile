import 'package:transaction_sync/write.dart' show bitcoinPsbtTransactionId;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' hide Network;

final class AppPayjoinBlockchainAdapter implements PayjoinBlockchainPort {
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _servers;
  final WalletFacade _wallet;

  const AppPayjoinBlockchainAdapter(
    this._blockchain,
    this._servers,
    this._wallet,
  );

  @override
  Future<void> broadcastTransaction({
    required BitcoinNetwork network,
    required Uint8List transaction,
  }) => _servers.runWithFallback<void>(
    network: ElectrumServerNetwork.fromNetworkEnv(network.env, isLiquid: false),
    operation: (connection) =>
        _blockchain.broadcastTransaction(transaction, connection: connection),
  );

  @override
  Future<void> broadcastPsbt({
    required String walletId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    final txid = bitcoinPsbtTransactionId(psbt);
    final result = await _wallet.broadcastBitcoin(walletId, network, () async {
      await _servers.runWithFallback<String>(
        network: ElectrumServerNetwork.fromNetworkEnv(
          network.env,
          isLiquid: false,
        ),
        operation: (connection) =>
            _blockchain.broadcastPsbt(psbt, connection: connection),
      );
      return txid;
    });
    if (result case Err(failure: WalletSpendBlockedFailure(:final status))) {
      throw PayjoinSpendBlockedException(
        busy: status == BitcoinSpendStatus.busy,
      );
    }
    // Accepted/local-record-pending remains accepted; the owner blocks further
    // spends. Never throw a post-accept local failure into the fallback catch.
  }
}
