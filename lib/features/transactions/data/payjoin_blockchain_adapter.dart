import 'package:sync/sync.dart' show bitcoinPsbtTransactionId;
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
  final String Function(String psbt) _transactionId;

  const AppPayjoinBlockchainAdapter(
    this._blockchain,
    this._servers,
    this._wallet, {
    this._transactionId = bitcoinPsbtTransactionId,
  });

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
    // Set on entering the network callback, before any server is contacted:
    // a failure while it is still false provably sent nothing.
    var reachedNetwork = false;
    final Result<BitcoinBroadcastReceipt, WalletSpendFailure> result;
    try {
      final txid = _transactionId(psbt);
      result = await _wallet.broadcastBitcoin(walletId, network, () async {
        reachedNetwork = true;
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
    } catch (_) {
      // Past the callback the outcome is unknown and stays untyped.
      if (reachedNetwork) rethrow;
      throw const PayjoinBroadcastNotAttemptedException();
    }
    if (result case Err(failure: WalletSpendBlockedFailure(:final status))) {
      throw PayjoinSpendBlockedException(
        busy: status == BitcoinSpendStatus.busy,
      );
    }
    // Accepted/local-record-pending remains accepted; the owner blocks further
    // spends. Never throw a post-accept local failure into the fallback catch.
  }
}
