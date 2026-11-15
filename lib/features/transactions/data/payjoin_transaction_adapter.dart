import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';

import 'dart:async';

import 'package:bb_mobile/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bull_payjoin/bull_payjoin.dart';

final class AppPayjoinTransactionAdapter implements PayjoinTransactionPort {
  static const _reconcileAttempts = 3;

  final WalletRepository _wallets;
  final WalletTransactionRepository _transactions;
  final BdkBitcoinBlockchainDatasource _blockchain;
  final ElectrumServersPort _servers;
  final WalletFacade? _spendWallet;
  // Pacing between two wallet syncs of [_reconcileWallet]; tests shorten it.
  final Duration reconcileDelay;

  const AppPayjoinTransactionAdapter(
    this._wallets,
    this._transactions,
    this._blockchain,
    this._servers, {
    this._spendWallet,
    this.reconcileDelay = const Duration(seconds: 5),
  });

  @override
  Future<bool> protectObservedSpend({
    required String walletId,
    required String transactionId,
  }) async =>
      _spendWallet?.protectObservedSpend(walletId, transactionId) ?? false;

  @override
  Stream<void> watchWallet(String walletId) => _wallets.walletSyncFinishedStream
      .where((wallet) => wallet.id == walletId);

  /// A refreshed lookup asks the Electrum server about this one transaction
  /// instead of syncing the whole wallet, which takes 15 to 120 seconds
  /// over Tor and delayed every payjoin outcome by as much.
  ///
  /// The wallet's own copy only answers a non-refreshed lookup: a pending
  /// transaction the wallet saw earlier can since have been evicted or
  /// replaced, and the engine settles sessions on this answer.
  @override
  Future<bool> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async {
    if (!refresh) {
      return await _transactions.getWalletTransaction(
            transactionId,
            walletId: walletId,
          ) !=
          null;
    }

    final wallet = (await _wallets.getWallet(walletId)).fold(
      (wallet) => wallet,
      (failure) =>
          throw Exception('Payjoin wallet unavailable: ${failure.runtimeType}'),
    );
    final bool isKnownRemotely;
    try {
      isKnownRemotely = await _servers.runWithFallback<bool>(
        network: ElectrumServerNetwork.fromNetworkEnv(
          wallet.network.environment,
          isLiquid: false,
        ),
        operation: (connection) => _blockchain.isTransactionKnown(
          transactionId,
          connection: connection,
        ),
        // Another server would word its reply the same way; surface it.
        isTransient: (e) =>
            e is Exception && e is! UnrecognizedElectrumReplyException,
      );
    } on UnrecognizedElectrumReplyException {
      // A server we cannot classify (Electrum Personal Server, bitcoind
      // without txindex): take the slow road of a script-based wallet sync
      // and read the wallet copy, instead of failing every lookup. A sync
      // can join a pass that started before the broadcast, so an absence is
      // only trusted after a second pass.
      for (var pass = 1; pass <= 2; pass++) {
        final transaction = await _transactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
          sync: true,
        );
        if (transaction != null) return true;
      }
      return false;
    }
    if (isKnownRemotely) {
      // Let the wallet catch up so balances and history show the transaction
      // the payjoin session is about to report.
      unawaited(_reconcileWallet(walletId, transactionId));
    }
    return isKnownRemotely;
  }

  /// Syncs until the wallet holds [transactionId], a few times at most: one
  /// sync can fail, or join a pass that started before the transaction was
  /// broadcast and so miss it. The session outcome never waits on this.
  Future<void> _reconcileWallet(String walletId, String transactionId) async {
    for (var attempt = 1; attempt <= _reconcileAttempts; attempt++) {
      if (attempt > 1) await Future<void>.delayed(reconcileDelay * attempt);
      try {
        await refreshWallet(walletId);
        final transaction = await _transactions.getWalletTransaction(
          transactionId,
          walletId: walletId,
        );
        if (transaction != null) {
          if (attempt > 1) {
            log.fine('Payjoin wallet reconcile recovered attempts=$attempt');
          }
          return;
        }
      } on Exception {
        // The final outcome below owns this bounded reconciliation.
      }
    }
    log.warning(
      'Payjoin wallet reconcile failed attempts=$_reconcileAttempts reason=unavailable',
    );
  }

  @override
  Future<void> refreshWallet(String walletId) async {
    // Refresh only: the caller wants the side-effecting sync, not the wallet.
    (await _wallets.getWallet(walletId, sync: true)).fold(
      (_) {},
      (failure) => throw Exception(
        'Payjoin wallet refresh failed: ${failure.runtimeType}',
      ),
    );
  }
}
