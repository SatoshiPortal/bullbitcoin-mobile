import 'package:sync/sync.dart'
    show
        SyncBusyFailure,
        SyncClosedFailure,
        SyncConnectionFailure,
        SyncInvalidTransactionFailure,
        SyncNotFoundFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure,
        SyncUnsupportedNetworkFailure;
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'dart:typed_data';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:electrum/electrum.dart';
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

  /// Through `wallet.tx.broadcast`, as session [sessionId]: the only one
  /// that may spend the inputs it reserved. The guard is held until the
  /// receipt.
  @override
  Future<void> broadcastPsbt({
    required String walletId,
    required String sessionId,
    required BitcoinNetwork network,
    required String psbt,
  }) async {
    final result = await _wallet.broadcastSpend(
      walletId,
      SignedPsbt(psbt),
      network: network,
      owner: SpendOwner(protocol: 'payjoin', session: sessionId),
    );
    switch (result) {
      case Ok():
        // Accepted, durably recorded or not: the guard keeps blocking
        // further spends meanwhile. Never a failure for the fallback.
        return;
      case Err(failure: SyncSpendBlockedFailure()):
        throw const PayjoinSpendBlockedException();
      case Err(failure: SyncBusyFailure()):
        throw const PayjoinSpendBlockedException(busy: true);
      // Refused before any server was contacted, or no server reachable
      // before the send: a connection lost after it is an unknown outcome.
      case Err(failure: SyncConnectionFailure()) ||
          Err(failure: SyncProtectedInputsFailure()) ||
          Err(failure: SyncNotFoundFailure()) ||
          Err(failure: SyncInvalidTransactionFailure()) ||
          Err(failure: SyncClosedFailure()) ||
          Err(failure: SyncUnsupportedNetworkFailure()):
        throw const PayjoinBroadcastNotAttemptedException();
      // A server may have relayed it: the outcome stays unknown.
      case Err(:final failure):
        throw StateError('Payjoin broadcast outcome: ${failure.logCode}');
    }
  }
}
