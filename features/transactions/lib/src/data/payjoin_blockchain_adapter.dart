import 'package:sync/sync.dart'
    show
        SignedPsbt,
        SpendOwner,
        WalletConnectionPort,
        broadcastBitcoinTransaction,
        SyncBusyFailure,
        SyncClosedFailure,
        SyncConnectionFailure,
        SyncInvalidTransactionFailure,
        SyncNotFoundFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure,
        SyncUnsupportedNetworkFailure;
import 'package:sync/write.dart' show BroadcastSpend;

import 'dart:typed_data';

import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart' hide Network;

final class AppPayjoinBlockchainAdapter implements PayjoinBlockchainPort {
  final WalletConnectionPort _connections;
  final BroadcastSpend _broadcast;

  const AppPayjoinBlockchainAdapter(this._connections, this._broadcast);

  @override
  Future<void> broadcastTransaction({
    required BitcoinNetwork network,
    required Uint8List transaction,
  }) async {
    final result = await broadcastBitcoinTransaction(
      transaction,
      network: network,
      connections: _connections,
    );
    if (result case Err(:final failure)) {
      throw Exception('Payjoin raw broadcast failed: ${failure.logCode}');
    }
  }

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
    final result = await _broadcast(
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
