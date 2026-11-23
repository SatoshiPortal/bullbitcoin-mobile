import 'dart:async';

import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart'
    show
        WalletConnectionPort,
        SyncFailure,
        SyncUnrecognizedReplyFailure,
        WalletKey,
        bitcoinTransactionKnown;

import '../../transactions.dart';

final class AppPayjoinTransactionAdapter implements PayjoinTransactionPort {
  static const _reconcileAttempts = 3;

  final WalletInventory _wallets;
  final Future<Result<void, SyncFailure>> Function(WalletKey) _synchronize;
  final Stream<WalletKey> _finished;
  final Transactions _transactions;
  final WalletConnectionPort _connections;
  final Future<bool> Function(String, String) _protectSpend;
  // Pacing between two wallet syncs of [_reconcileWallet]; tests shorten it.
  final Duration reconcileDelay;

  const AppPayjoinTransactionAdapter(
    this._wallets,
    this._transactions,
    this._connections, {
    required Future<Result<void, SyncFailure>> Function(WalletKey) synchronize,
    required Stream<WalletKey> finished,
    required Future<bool> Function(String, String) protectSpend,
    this.reconcileDelay = const Duration(seconds: 5),
  }) : _synchronize = synchronize,
       _finished = finished,
       _protectSpend = protectSpend;

  @override
  Future<bool> protectObservedSpend({
    required String walletId,
    required String transactionId,
  }) => _protectSpend(walletId, transactionId);

  @override
  Stream<void> watchWallet(String walletId) => _finished
      .where((key) => key.id == walletId && key.network is BitcoinNetwork)
      .asyncMap(
        (key) async => switch (await _wallets.readWallet(key.id)) {
          Ok(:final value) => value.network == key.network,
          Err() => false,
        },
      )
      .where((admitted) => admitted)
      .map((_) {});

  /// A refreshed lookup asks the Electrum server about this one transaction
  /// instead of syncing the whole wallet, which takes 15 to 120 seconds
  /// over Tor and delayed every payjoin outcome by as much.
  ///
  /// The wallet's own copy only answers a non-refreshed lookup: a pending
  /// transaction the wallet saw earlier can since have been evicted or
  /// replaced, and the engine settles sessions on this answer.
  @override
  Future<bool?> isTransactionVisible({
    required String walletId,
    required String transactionId,
    bool refresh = false,
  }) async {
    if (!refresh) {
      return _readTransaction(walletId, transactionId);
    }

    final key = await _readKey(walletId);
    final network = key.network;
    if (network is! BitcoinNetwork) {
      throw Exception('Payjoin requires a Bitcoin wallet');
    }
    final result = await _connections.run(
      network: network,
      operation: (connection) =>
          bitcoinTransactionKnown(transactionId, connection),
      mayRetry: (failure) => failure is! SyncUnrecognizedReplyFailure,
    );
    switch (result) {
      case Ok(:final value):
        if (value) {
          unawaited(_reconcileWallet(walletId, transactionId));
        }
        return value;
      case Err(failure: SyncUnrecognizedReplyFailure()):
        // A server we cannot classify (Electrum Personal Server, bitcoind
        // without txindex): take the slow road of a script-based wallet sync
        // and read the wallet copy, instead of failing every lookup. A sync
        // can join a pass that started before the broadcast, so an absence is
        // only trusted after a second pass.
        for (var pass = 1; pass <= 2; pass++) {
          final visible = await _readTransaction(
            walletId,
            transactionId,
            sync: true,
          );
          if (visible != false) return visible;
        }
        return false;
      case Err(:final failure):
        throw Exception(
          'Payjoin transaction lookup failed: ${failure.logCode}',
        );
    }
  }

  /// Syncs until the wallet holds [transactionId], a few times at most: one
  /// sync can fail, or join a pass that started before the transaction was
  /// broadcast and so miss it. The session outcome never waits on this.
  Future<void> _reconcileWallet(String walletId, String transactionId) async {
    for (var attempt = 1; attempt <= _reconcileAttempts; attempt++) {
      if (attempt > 1) await Future<void>.delayed(reconcileDelay * attempt);
      try {
        await refreshWallet(walletId);
        if (await _readTransaction(walletId, transactionId) == true) {
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

  Future<bool?> _readTransaction(
    String walletId,
    String transactionId, {
    bool sync = false,
  }) async {
    return switch (await _transactions.getWalletTransaction(
      transactionId,
      walletId: walletId,
      sync: sync,
    )) {
      Ok(:final value) => value != null,
      Err(:final failure) => _unavailable(failure),
    };
  }

  bool? _unavailable(TransactionFailure failure) {
    log.warning('Payjoin wallet history unavailable: ${failure.runtimeType}');
    return null;
  }

  @override
  Future<void> refreshWallet(String walletId) async {
    final result = await _synchronize(await _readKey(walletId));
    if (result case Err(:final failure)) {
      throw Exception('Payjoin wallet refresh failed: ${failure.logCode}');
    }
  }

  Future<WalletKey> _readKey(String id) async =>
      switch (await _wallets.readWallet(id)) {
        Ok(:final value) => WalletKey(id: value.id, network: value.network),
        Err(:final failure) => throw Exception(
          'Payjoin wallet unavailable: ${failure.runtimeType}',
        ),
      };
}
